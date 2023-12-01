import numpy as np
import os
import matplotlib as mpl
import matplotlib.pyplot as plt
import pandas as pd
from scipy.optimize import curve_fit

mpl.rcParams['pdf.fonttype'] = 42
import seaborn as sns

palette = sns.color_palette("tab10")
wdir = os.path.join(os.getcwd(), 'Math_Modelling', 'itn_effect_sizes', 'parameterization', 'figures')


def add_bfa_survival(plt):
    ## Digitized data points from 2022_Q2_interim_report_2022July15.pdf Figure BF5. E
    ## https://media.path.org/documents/2022_Q2_interim_report_2022July15.pdf
    t_yrs = [0, 0.4, 1.1] + [0, 0.1, 0.8] + [0, 0.5, 1.2]
    survival = [100, 99, 85] + [100, 99, 95] + [100, 98, 89]
    areas = ['Gaouma'] * 3 + ['Banfora'] * 3 + ['Orodara'] * 3

    df = pd.DataFrame({'t_yrs': t_yrs, 'survival': survival, 'areas': areas})
    plt.plot(df['t_yrs'], df['survival'] / 100, 'o', label='BFA new nets project data')

    return plt


def weib_decay_func(x, L, k):
    return np.exp(-(x / L) ** k * np.log(2))


def fit_func_to_boxexpo(initial_effect, num_years, dt):
    numsteps = int(1 / dt * num_years)
    box_dur = 1.5
    box_exp_halflife = 0.75
    box_decay_time, decay_vec = get_decay(initial_effect, box_exp_halflife / np.log(2), numsteps, dt)

    box_time = [dt * x for x in range((int(box_dur / dt)))]
    box_time = box_time + [x + box_dur for x in box_decay_time]
    box_time = box_time[:numsteps]
    box_eff = [initial_effect] * (int(box_dur / dt))
    box_eff = box_eff + decay_vec
    box_eff = box_eff[:numsteps]

    xdata = box_time
    ydata = box_eff
    plt.plot(xdata, ydata, color='black', label='box exponential')

    ## compare to default
    emod_time, emod_curr_vec = get_decay(initial_effect, 730 / 365, numsteps, dt)
    plt.plot(emod_time, emod_curr_vec, color='red', label='emod default')
    plt.plot(emod_time, [0.5 * initial_effect] * len(emod_time), '--k')

    params, ypred = curve_fit(weib_decay_func, xdata, ydata)

    # plt.plot(xdata, weib_decay_func(xdata, *params), color=palette[0], label='fit: L=%5.3f, k=%5.3f' % tuple(params))
    plt.plot(xdata, weib_decay_func(xdata, *np.array([2.5, 2.3])), color=palette[1], label='fit: L=2.5, k= 2.3')
    plt.plot(xdata, weib_decay_func(xdata, *np.array([2.39, 2.3])), color=palette[2], label='fit: L=2.39, k= 2.3')

    add_bfa_survival(plt)
    plt.legend()

    plt.xlabel('years')
    plt.ylabel('effect')
    plt.title('retention of nets')
    plt.savefig(os.path.join(wdir, 'retention_new.png'))
    plt.savefig(os.path.join(wdir, 'retention_new.pdf'), format='PDF')

    return params


def get_weibull_decay(initial_eff, L, numsteps, dt, k):
    current_effect = 1 * initial_eff
    curr_vec = []
    time = []
    for i in range(numsteps):
        curr_vec.append(current_effect)
        time.append(i * dt)

    curr_vec = weib_decay_func(time, *np.array([L, k]))
    return time, curr_vec


def get_decay(initial_eff, decay_time_const, numsteps, dt):
    current_effect = 1 * initial_eff
    curr_vec = []
    time = []
    for i in range(numsteps):
        curr_vec.append(current_effect)
        time.append(i * dt)
        current_effect *= (1 - dt / decay_time_const)  # 1 - t/L
    return time, curr_vec


def blocking(num_years, dt):
    numsteps = int(1 / dt * num_years)
    initial_effect = 1
    decayTimeConstant = 730 / 365

    fig = plt.figure()
    ax = fig.gca()

    emod_time, emod_curr_vec = get_decay(initial_effect, decayTimeConstant, numsteps, dt)
    ax.plot(emod_time, emod_curr_vec, 'r', label='emod default')
    ax.plot(emod_time, [0.5 * initial_effect] * len(emod_time), '--k')

    box_dur = 0.5
    box_exp_halflife = 1.5
    box_decay_time, decay_vec = get_decay(initial_effect, box_exp_halflife / np.log(2), numsteps, dt)

    box_time = [dt * x for x in range((int(box_dur / dt)))]
    box_time = box_time + [x + box_dur for x in box_decay_time]
    box_time = box_time[:numsteps]
    box_eff = [initial_effect] * (int(box_dur / dt))
    box_eff = box_eff + decay_vec
    box_eff = box_eff[:numsteps]

    ax.plot(box_time, box_eff, 'b', label='box_exp %.1f %.2f' % (box_dur, box_exp_halflife))

    nnp_halflife = 2.5
    nnp_time, nnp_curr_vec = get_decay(initial_effect, nnp_halflife / np.log(2), numsteps, dt)
    ax.plot(nnp_time, nnp_curr_vec, 'g', label='nnp_exp %.1f' % nnp_halflife)

    ax.set_xlabel('years')
    ax.set_ylabel('effect')
    ax.set_ylim(0, )
    ax.legend()
    ax.set_title('blocking')
    plt.savefig(os.path.join(wdir, 'blocking.png'))
    plt.savefig(os.path.join(wdir, 'blocking.pdf'), format='PDF')


def retention(num_years, dt, add_distribution=None):
    numsteps = int(1 / dt * num_years)
    initial_effect = 1
    decayTimeConstant = 1.7

    fig = plt.figure()
    ax = fig.gca()

    emod_time, emod_curr_vec = get_decay(initial_effect, decayTimeConstant, numsteps, dt)

    if 'weibull' in add_distribution:
        L = 2.5
        k = 2.3
        weibull_time, weibull_decay_vec = get_weibull_decay(initial_effect, L, numsteps, dt, k)

    box_dur = 1.5
    box_exp_halflife = 0.75
    box_decay_time, decay_vec = get_decay(initial_effect, box_exp_halflife / np.log(2), numsteps, dt)

    box_time = [dt * x for x in range((int(box_dur / dt)))]
    box_time = box_time + [x + box_dur for x in box_decay_time]
    box_time = box_time[:numsteps]
    box_eff = [initial_effect] * (int(box_dur / dt))
    box_eff = box_eff + decay_vec
    box_eff = box_eff[:numsteps]

    ax.plot(emod_time, emod_curr_vec, 'r', label='emod default')
    ax.plot(emod_time, [0.5 * initial_effect] * len(emod_time), '--k')

    ax.plot(box_time, box_eff, 'b', label='box_exp %.1f %.2f' % (box_dur, box_exp_halflife))

    if 'weibull' in add_distribution:
        ax.plot(weibull_time, weibull_decay_vec, 'g', label='weibull lambda=%.1f, kappa=%.2f' % (L, k))

    ax.set_xlabel('years')
    ax.set_ylabel('effect')
    ax.set_ylim(0, )
    ax.legend()
    ax.set_title('retention')
    plt.savefig(os.path.join(wdir, 'retention.png'))
    plt.savefig(os.path.join(wdir, 'retention.pdf'), format='PDF')


def killing(num_years, dt):
    numsteps = int(1 / dt * num_years)
    initial_effect = 1
    decayTimeConstant = 1460 / 365

    fig = plt.figure()
    ax = fig.gca()

    emod_time, emod_curr_vec = get_decay(initial_effect, decayTimeConstant, numsteps, dt)
    ax.plot(emod_time, emod_curr_vec, 'r', label='emod default')
    ax.plot(emod_time, [0.5 * initial_effect] * len(emod_time), '--k')

    ax.set_xlabel('years')
    ax.set_ylabel('effect')
    ax.set_ylim(0, )
    ax.legend()
    ax.set_title('killing')
    plt.savefig(os.path.join(wdir, 'killing.png'))
    plt.savefig(os.path.join(wdir, 'killing.pdf'), format='PDF')


if __name__ == '__main__':
    num_years = 10
    dt = 0.01

    # params = fit_func_to_boxexpo(1, num_years, dt)  ## to get Lambda and Kappa for Weibull, retention plot

    blocking(num_years, dt)
    killing(num_years, dt)
    retention(num_years, dt, add_distribution='weibull')
    plt.show()
