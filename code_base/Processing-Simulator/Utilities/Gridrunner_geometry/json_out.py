import Rhino.Geometry as rg
import rhinoscriptsyntax as rs
import json
from System.Drawing import Color

dotObjects = rs.GetObjects("Select text dots", 8192)

with open("C:\\Users\\timothyb\\downloads\\gridrunner_meander_json_vertices_TBedit.json",'wb') as f:
    jd = {} #json dict
    for dot in dotObjects:
        text = rs.TextDotText(dot)
        point = rs.TextDotPoint(dot)
        if text not in jd.keys():
            jd[text] = []
        jd[text].append({'x': point.X, 'y':point.Y, 'z':point.Z})
    f.write(json.dumps(jd, indent = 4, sort_keys=True))