import csv
import os

print("CSV converter tool written by Niel Mistry. Supported by Python 2.7")

file_path = raw_input("Please enter the path of the file you wish to convert: ")

# get the header
header = []
with open(file_path, 'rU') as f:
    reader = csv.reader(f)
    i = reader.next()
    header = i

csvDict = [{}]

# Imports the csv as a dictionary
with open(file_path, 'rU') as csvfile:
    reader = csv.DictReader(csvfile)
    csvDict = list(reader)

os.rename(file_path,file_path + ".old")

seen_nodes = dict()
seen_pis = dict()
sensors = ['GE','SD']

# for every row in the csv 
for row in csvDict:
    # Change the types for Grideyes

    if row['DEVICE'] is 'GE':
        row['NODE_TYPE'] = 'GN'
        if "HU" in row['GROUP']:
            print("Changing HU to GE in group name for group " + row['GROUP']  + "... \n")
            row['GROUP'].replace('HU','GE')
    else:
        row['NODE_TYPE'] = 'HU'

    cur_node = row['GROUP']
    cur_pi = cur_node.split(':')[0] + cur_node.split(':')[1]

    if cur_node not in seen_nodes:
        if(row["NODE ID"] is ""):
            seen_nodes[cur_node] = raw_input("Please enter the node ID for " + cur_node + ": ")
        else:
            seen_nodes[cur_node] = row["NODE ID"]
    if cur_pi not in seen_pis:
        if(row["PI IP"] is ""):
            seen_pis[cur_pi] = raw_input("Please enter the Pi IP for " + cur_pi + ": ")
        else:
            seen_pis[cur_pi] = row["PI IP"]

    row["PI IP"] = seen_pis[cur_pi]
    row["NODE ID"] = seen_nodes[cur_node]

    if row['DEVICE'] in sensors:
        row['DEVICE_TYPE'] = "sensor"
    else:
        row['DEVICE_TYPE'] = "actuator"


headersToAdd = ['CONTROL IP','PI IP','NODE ID','DEVICE_TYPE','CONFIG','INSTALLED','NODE_TYPE']

for item in headersToAdd:
    if item not in header:
        header.append(item)

with open(file_path, mode='wb') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=header, dialect='excel')
    writer.writeheader()

    for row in csvDict:
        writer.writerow(row)
    
  

