

import rhinoscriptsyntax as rs
import Rhino.Geometry as rg
import Rhino

def editTextDots():
    rs.EnableRedraw(False)
    allDots = rs.GetObjects("Select text dots to edit:", 8192, preselect = True)
    key = rs.GetString("Substring to replace in text dot text string:", defaultString = "@") 
    replace = rs.GetString("Text to replace with:", defaultString = "1") 
    for dot in allDots:
        if rs.IsTextDot(dot):
            dotText = rs.TextDotText(dot)
            newText = dotText.replace(key, replace)
            dotPoint = rs.coerce3dpoint(rs.TextDotPoint(dot))
            rs.TextDotText(dot, newText)
    rs.EnableRedraw(True)
    rs.Redraw()


editTextDots()