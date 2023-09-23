### Extract EPI vaccination coverage from Guinea DHS 2018

|[Guide-to-DHS-Statistics/Vaccination](https://dhsprogram.com/data/Guide-to-DHS-Statistics/Vaccination.htm)|  


**Scripts:**
1. `functions.R`: Specific helper functions for retrieving and handling DHS/MIS data
2. `00_write_cluster_DS.R`: Load household clusters from DHS and match them to admin2 boundaries for Guinea
2. `01_extract_EPIcov.R`:  Extract percentage of children 12-23 months who had received vaccinations, reported in DHS 2018
3. `02_make_pmc_rtss_operational_cov.R`: Transform EPI extracted coverage to appropriate input for RTS,S and PMC coverages files
4. `03_describe_coverage.R`: Generate maps and figures to describe RTS,S and PMC coverage


**Under ../setup_intervention_input:**  
- `pmc_2023-2029.R`  
- `rtss_2023_2029.R`  


