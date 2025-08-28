""" 
- Open the OpenFAST binary file for each simulation
- Convert it to a pandas dataframe
- Compute damage equivalent load for a given Wohler exponent

- For each variable in 'var', create a csv file with all the DEL simulation data
"""
import csv
import numpy as np
from getSimRes import getSimRes

# Define posible values for Wöhler exponent
m_values = {'LSSGagMya_[kN-m]': 4, 'LSSGagMza_[kN-m]': 4, 'TwrBsMxt_[kN-m]': 4, 'TwrBsMyt_[kN-m]': 4}
for i in range(1,3):
    m_values['RootMxb' + str(i) + '_[kN-m]'] = 10
    m_values['RootMyb' + str(i) + '_[kN-m]'] = 10
print(m_values)
# Variable whose values will be written in the csv file
variables = ['RootMxb1_[kN-m]'] # RootMxb1_[kN-m], RootMyb1_[kN-m], RootMxb2_[kN-m], ..., LSSGagMya_[kN-m], LSSGayMza_[kN-m], TwrBsMxt_[kN-m], TwrBsMyt_[kN-m]

# Agrego FG
DLC_choice = '2p1'  # flexible; rigid
U = '14.0'
variation = ''#'_ROSCO_SDTime' #'_PitchMan'#'_ROSCO_TurbS_'  #'_PM_'#  'PM_SinGen'
tech_f = '_'#'ROSCO_TurbS' #'2p1_PM'#
root_name = 'IEA-3.4-130-RWT_'

for var in variables:

    m = m_values[var]

    # Define constant values for getSimRes function
    Teq = 1
    bins = 100  # int o list
    if isinstance(bins, int):
        nbins = bins
    elif isinstance(bins, list):
        nbins = len(bins) - 1*(len(bins) > 1)

    columns = ["Simulation Name", "Leq", "S", "N", "bins", "DELi"]
    columns = ["Simulation Name", "Leq"] + ["S_{}".format(i) for i in range(1, nbins + 1)] + \
            ["N_{}".format(i) for i in range(1, nbins + 1)] + \
            ["bins_{}".format(i) for i in range(1, nbins + 2)] + \
            ["DELi_{}".format(i) for i in range(1, nbins + 1)]

    with open(var + '.csv', 'w', newline='') as csv_file:

        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(columns)

        for v in np.arange(4.0,26.0,1.0):
            print(v)
        #for v in [8.0,20.0]:
            # Get simulation name and results
            simName = f'{root_name}{DLC_choice}_{str(v)}.outb'
            Leq, S, N, bins, DELi = getSimRes(simName, var, m, Teq, bins, DLC_choice, variation,v)
            print(Leq)
            # Add row in the csv file
            csv_writer.writerow([simName, Leq] + S.tolist() + N.tolist() + bins.tolist() + DELi.tolist())