from datetime import datetime
import os
import numpy as np
import pandas as pd
from idmtools.entities import IAnalyzer
from idmtools.entities.simulation import Simulation


class MonthlyAgebinPfPRAnalyzer(IAnalyzer):
    """
    Take monthly MalariaSummaryReport and pull out the PfPR, Cases, Severe Cases
    and Population for each agebins.
    """

    def __init__(
        self,
        sweep_variables=None,
        working_dir="./",
        start_year=2000,
        end_year=2001,
        filter_exists=False,
    ):
        super(MonthlyAgebinPfPRAnalyzer, self).__init__(
            working_dir=working_dir,
            filenames=[
                f"output/MalariaSummaryReport_Monthly{x}.json"
                for x in range(start_year, end_year)
            ],
        )

        self.sweep_variables = sweep_variables or ["Run_Number"]
        self.start_year = start_year
        self.end_year = end_year
        self.filter_exists = filter_exists

    def filter(self, simulation: Simulation):
        if self.filter_exists:
            file = os.path.join(simulation.get_path(), self.filenames[0])
            return os.path.exists(file)
        else:
            return True

    def map(self, data, simulation: Simulation):
        adf = []
        fname = self.filenames[0]

        for year, fname in zip(range(self.start_year, self.end_year), self.filenames):
            age_bins = data[fname]["Metadata"]["Age Bins"]
            df = pd.DataFrame.from_dict(
                data[fname]["DataByTimeAndAgeBins"], orient="columns"
            )[:-1]
            df["month"] = [[x] * len(age_bins) for x in range(1, len(df) + 1)]
            df["agebin"] = [age_bins] * len(df)
            df.rename(
                columns={
                    "PfPR by Age Bin": "PfPR",
                    "Annual Clinical Incidence by Age Bin": "Cases",
                    "Annual Severe Incidence by Age Bin": "Severe cases",
                    "New Infections by Age Bin": "New infections",
                    "Average Population by Age Bin": "Pop",
                },
                inplace=True,
            )
            df = df[
                [
                    "agebin",
                    "month",
                    "PfPR",
                    "Cases",
                    "Severe cases",
                    "New infections",
                    "Pop",
                ]
            ]
            df = df.explode(list(df.columns))
            df["year"] = year
            adf = adf + [df]

        adf = pd.concat(adf)

        for sweep_var in self.sweep_variables:
            if sweep_var in simulation.tags.keys():
                adf[sweep_var] = simulation.tags[sweep_var]

        return adf

    def reduce(self, all_data):
        selected = [data for sim, data in all_data.items()]
        if len(selected) == 0:
            print("\nWarning: No data have been returned... Exiting...")
            return

        print(f"\nSaving outputs to: {self.working_dir}")

        adf = pd.concat(selected).reset_index(drop=True)
        adf.to_csv(
            (
                os.path.join(
                    self.working_dir,
                    "Agebin_PfPR_ClinicalIncidence_monthly.csv",
                )
            ),
            index=False,
        )


class MonthlyTreatedCasesAnalyzer(IAnalyzer):
    """
    Take monthly ReportEventCounter and ReportMalariaFiltered and pull out the
    cases and treated cases for all age.
    """

    def __init__(
        self,
        sweep_variables,
        channels=None,
        working_dir="./",
        start_year=2000,
        end_year=2001,
        filter_exists=False,
    ):
        super(MonthlyTreatedCasesAnalyzer, self).__init__(
            working_dir=working_dir,
            filenames=[
                "output/ReportEventCounter.json",
                "output/ReportMalariaFiltered.json",
            ],
        )

        self.sweep_variables = sweep_variables
        self.channels = channels or [
            "Received_Treatment",
            "Received_Severe_Treatment",
            "Received_NMF_Treatment",
        ]
        self.inset_channels = [
            "Statistical Population",
            "New Clinical Cases",
            "New Severe Cases",
            "PfHRP2 Prevalence",
        ]
        self.start_year = start_year
        self.end_year = end_year
        self.filter_exists = filter_exists

    def filter(self, simulation: Simulation):
        if self.filter_exists:
            x = [
                os.path.exists(os.path.join(simulation.get_path(), f))
                for f in self.filenames
            ]
            return all(x)
        else:
            return True

    def map(self, data, simulation: Simulation):
        simdata = pd.DataFrame(
            {
                x: data[self.filenames[1]]["Channels"][x]["Data"]
                for x in self.inset_channels
            }
        )
        simdata["Time"] = simdata.index

        if self.channels:
            d = pd.DataFrame(
                {
                    x: data[self.filenames[0]]["Channels"][x]["Data"]
                    for x in self.channels
                }
            )
            d["Time"] = d.index
            simdata = pd.merge(left=simdata, right=d, on="Time")

        simdata["Day"] = simdata["Time"] % 365
        simdata["Month"] = (simdata["Time"] % 365 - 1) // 30 + 1
        simdata["Year"] = simdata["Time"].apply(
            lambda x: int(x / 365) + self.start_year
        )
        simdata = simdata[simdata["Month"].isin(list(range(1, 13)))]
        simdata["date"] = simdata.apply(
            lambda x: datetime.date(int(x["Year"]), int(x["Month"]), 1), axis=1
        )

        sum_channels = [
            "Received_Treatment",
            "Received_Severe_Treatment",
            "New Clinical Cases",
            "New Severe Cases",
            "Received_NMF_Treatment",
        ]
        for x in [y for y in sum_channels if y not in simdata.columns.values]:
            simdata[x] = 0
        mean_channels = ["Statistical Population", "PfHRP2 Prevalence"]

        df = simdata.groupby(["date"])[sum_channels].agg(np.sum).reset_index()
        pdf = simdata.groupby(["date"])[mean_channels].agg(np.mean).reset_index()

        simdata = pd.merge(left=pdf, right=df, on=["date"])

        for sweep_var in self.sweep_variables:
            if sweep_var in simulation.tags.keys():
                simdata[sweep_var] = simulation.tags[sweep_var]
        return simdata

    def reduce(self, all_data):
        selected = [data for sim, data in all_data.items()]
        if len(selected) == 0:
            print("\nWarning: No data have been returned... Exiting...")
            return

        print(f"\nSaving outputs to: {self.working_dir}")

        adf = pd.concat(selected).reset_index(drop=True)
        adf.to_csv(
            (
                os.path.join(
                    self.working_dir, "All_Age_Monthly_Cases.csv"
                )
            ),
            index=False,
        )


class AnnualAgebinPfPRAnalyzer(IAnalyzer):
    """
    Take monthly MalariaSummaryReport and pull out the PfPR, Cases, Severe Cases
    and Population for each agebins.
    """

    def __init__(
        self,
        sweep_variables=None,
        working_dir="./",
        start_year=2000,
        end_year=2001,
        filter_exists=False,
    ):
        super(AnnualAgebinPfPRAnalyzer, self).__init__(
            working_dir=working_dir,
            filenames=[
                f"output/MalariaSummaryReport_Annual_{start_year}to{end_year}.json"
            ],
        )

        self.sweep_variables = sweep_variables or ["Run_Number"]
        self.start_year = start_year
        self.end_year = end_year
        self.filter_exists = filter_exists

    def filter(self, simulation: Simulation):
        if self.filter_exists:
            file = os.path.join(simulation.get_path(), self.filenames[0])
            return os.path.exists(file)
        else:
            return True

    def map(self, data, simulation: Simulation):
        fname = self.filenames[0]

        age_bins = data[fname]["Metadata"]["Age Bins"]
        df = pd.DataFrame.from_dict(
            data[fname]["DataByTimeAndAgeBins"], orient="columns"
        )
        df["year"] = [
            [x] * len(age_bins) for x in range(self.start_year, self.end_year + 1)
        ]
        df["agebin"] = [age_bins] * len(df)
        df.rename(
            columns={
                "PfPR by Age Bin": "PfPR",
                "Annual Clinical Incidence by Age Bin": "Cases",
                "Annual Severe Incidence by Age Bin": "Severe cases",
                "New Infections by Age Bin": "New infections",
                "Average Population by Age Bin": "Pop",
            },
            inplace=True,
        )
        df = df[
            ["agebin", "year", "PfPR", "Cases", "Severe cases", "New infections", "Pop"]
        ]
        df = df.explode(list(df.columns))

        for sweep_var in self.sweep_variables:
            if sweep_var in simulation.tags.keys():
                df[sweep_var] = simulation.tags[sweep_var]

        return df

    def reduce(self, all_data):
        selected = [data for sim, data in all_data.items()]
        if len(selected) == 0:
            print("\nWarning: No data have been returned... Exiting...")
            return

        print(f"\nSaving outputs to: {self.working_dir}")

        adf = pd.concat(selected).reset_index(drop=True)
        adf.to_csv(
            (
                os.path.join(
                    self.working_dir,
                    "Agebin_PfPR_ClinicalIncidence_annual.csv",
                )
            ),
            index=False,
        )


class annualSevereTreatedByAgeAnalyzer(IAnalyzer):
    """
    Take monthly ReportEventCounter and ReportMalariaFiltered and pull out the
    cases and treated cases for all age.
    """

    def __init__(
        self,
        event_name="Received_Severe_Treatment",
        agebins=None,
        sweep_variables=None,
        working_dir="./",
        start_year=2000,
        ds_col="DS_Name",
        filter_exists=False,
    ):
        super(annualSevereTreatedByAgeAnalyzer, self).__init__(
            working_dir=working_dir,
            filenames=[
                "output/ReportEventRecorder.csv",
            ],
        )

        self.sweep_variables = sweep_variables
        self.event_name = event_name
        self.agebins = agebins or [1, 5, 125]
        self.start_year = start_year
        self.ds_col = ds_col
        self.filter_exists = filter_exists

    def filter(self, simulation: Simulation):
        if self.filter_exists:
            x = [
                os.path.exists(os.path.join(simulation.get_path(), f))
                for f in self.filenames
            ]
            return all(x)
        else:
            return True

    def map(self, data, simulation: Simulation):
        output_data = data[self.filenames[0]].copy() 
        output_data = output_data[output_data["Event_Name"] == self.event_name]

        simdata = pd.DataFrame()
        if len(output_data) > 0:  # there are events of this type
            output_data["Day"] = output_data.loc[:, "Time"] % 365
            output_data["year"] = output_data.loc[:, "Time"].apply(
                lambda x: int(x / 365) + self.start_year
            )
            output_data["age in years"] = output_data.loc[:, "Age"] / 365

            list_of_g = []
            for agemax in self.agebins:
                agemin = 0
                d = output_data[
                    (output_data["age in years"] < agemax)
                    & (output_data["age in years"] > agemin)
                ]
                g = d.groupby(["year"])["Event_Name"].agg(len).reset_index()
                g = g.rename(columns={"Event_Name": self.event_name})
                g["agebin"] = agemax

                list_of_g = list_of_g + [g]

            simdata = pd.concat(list_of_g).reset_index(drop=True)

            for sweep_var in self.sweep_variables:
                if sweep_var in simulation.tags.keys():
                    simdata[sweep_var] = simulation.tags[sweep_var]
        else:
            simdata = pd.DataFrame(
                columns=["year", self.event_name] + self.sweep_variables
            )
        return simdata

    def reduce(self, all_data):
        selected = [data for sim, data in all_data.items()]
        if len(selected) == 0:
            print("\nWarning: No data have been returned... Exiting...")
            return

        print(f"\nSaving outputs to: {self.working_dir}")

        adf = pd.concat(selected).reset_index(drop=True)
        adf.to_csv(
            (
                os.path.join(
                    self.working_dir,
                    "Treated_Severe_Yearly_Cases_By_Age.csv",
                )
            ),
            index=False,
        )


class EventReporterAnalyzer(IAnalyzer):
    '''
    Pull out the ReportEventRecorder and stack them together.
    '''

    def __init__(self, sweep_variables=None, working_dir='./', time_cutoff = 0):
        super(EventReporterAnalyzer, self).__init__(working_dir=working_dir,
                                                    filenames=["output/ReportEventRecorder.csv"])
        self.sweep_variables = sweep_variables
        self.time_cutoff = time_cutoff

    def map(self, data, simulation: Simulation):

        df = data[self.filenames[0]]
        df = df[df['Time'] >= self.time_cutoff].copy()

        # add tags
        for sweep_var in self.sweep_variables:
            if sweep_var in simulation.tags.keys():
                df[sweep_var] = simulation.tags[sweep_var]

        return df

    def reduce(self, all_data):
        selected = [data for sim, data in all_data.items()]
        if len(selected) == 0:
            print("\nWarning: No data have been returned... Exiting...")
            return

        print(f'\nSaving outputs to: {self.working_dir}')

        adf = pd.concat(selected).reset_index(drop=True)
        adf.to_csv((os.path.join(self.working_dir, 'events.csv')),
                   index=False, index_label=False)