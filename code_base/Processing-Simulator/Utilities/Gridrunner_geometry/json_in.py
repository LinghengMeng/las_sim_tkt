import Rhino.Geometry as rg
import rhinoscriptsyntax as rs
import json
from System.Drawing import Color

rs.CurrentLayer("correct")

with open("C:\\Users\\timothyb\\downloads\\gridrunner_meander_json_vertices2.json",'rb') as f:
    data = json.load(f)
    for point in data:
#        print group
        group = "."
        x = point['x']
        y = point['y']
        z = point['z']
        rs.AddTextDot(str(group),rg.Point3f(x,y,z))


if rs.LayerId("to fix") is not None:
    rs.CurrentLayer("to fix")
else:
    rs.AddLayer("to fix", color = Color.Red)


with open("C:\\Users\\timothyb\\downloads\\gridrunner_meander_json_vertices4.json",'rb') as f:
    data = json.load(f)
    print data
    for group in data:
        rs.AddLayer(name = group, color = Color.DarkSeaGreen, parent = "to fix")
        rs.CurrentLayer(group)
#        print group
        for point in data[group]:
#            print point
            x = point['x']
            y = point['y']
            z = point['z']
            rs.AddTextDot(str(group),rg.Point3f(x,-1*y,z))

#print data['Hex Grid NR'][1]["x"]
