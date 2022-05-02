import rhinoscriptsyntax as rs
import csv

centerDot = rs.GetObject("Select Center Point", 8192)
ptCtr = rs.TextDotPoint(centerDot)
dotObjects = rs.GetObjects("Select Text Dots", 8192) # input your text dots

with open("output.csv",'wb') as f:
    writer = csv.writer(f, delimiter =',')
    writer.writerow(["GROUP", "DEVICE", "NUM", "UID", "X", "Y", "Z", "T_X", "T_Y", "T_Z"]) 
    for dotObject in dotObjects: # for each text dot, i.e. each object in the collection
        text = rs.TextDotText(dotObject)
        point = rs.TextDotPoint(dotObject)
        splits = text.split(':')
        if len(splits) > 1:
            GROUP = splits[0] + ":" + splits[1] + ":" + splits[2] + ":" + splits[3]
            DEVICE = splits[4]
            if len(splits) < 6:
                NUM = "--"
                UID = "--"
            else:
                NUM = splits[5]
                UID = splits[6]
            X = point.X
            Y = point.Y
            Z = point.Z
            line = [GROUP,DEVICE,NUM,UID,X,Y,Z,ptCtr.X, ptCtr.Y, ptCtr.Z]
            writer.writerow(line)