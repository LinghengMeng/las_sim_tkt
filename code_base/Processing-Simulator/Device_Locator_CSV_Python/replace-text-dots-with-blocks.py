

import rhinoscriptsyntax as rs
import Rhino.Geometry as rg
import Rhino

def replaceTextDotsWithBlocks():
    allDots = rs.GetObjects("Select text dots to populate:", 8192, preselect = True)
    for dot in allDots:
        text = rs.TextDotText(dot)
        point = rs.TextDotPoint(dot)
        splits = text.split(':')
        if rs.IsTextDot(dot) and len(splits) > 1:
            groupType = splits[0]         # '%' --> 'SG'
            groupNumber = splits[1]       # '@' --> 0
            clusterType = splits[2]       # [switch]
            clusterNumber = splits[3]     # '#' --> 1
            blockName = "DL:" + clusterType
            thisBlock = rs.InsertBlock(blockName, point)
            dotsInBlock = rs.ExplodeBlockInstance(thisBlock)
            for bDot in dotsInBlock:
                if rs.IsTextDot(bDot):
                    bText = rs.TextDotText(bDot)
                    bPoint = rs.TextDotPoint(bDot)
                    bNewText = bText.replace('%', groupType).replace('@', groupNumber).replace('#', clusterNumber)
                    bDotPoint = rs.coerce3dpoint(rs.TextDotPoint(bDot))
                    rs.TextDotText(bDot, bNewText)
                
            
            
#            GROUP = splits[0] + ":" + splits[1] + ":" + splits[2] + ":" + splits[3]
#            DEVICE = splits[4]
#            if len(splits) < 6:
#                NUM = "--"
#                UID = "--"
#            else:
#                NUM = splits[5]
#                UID = "--"
#            X = point.X
#            Y = point.Y
#            Z = point.Z
#            line = [GROUP,DEVICE,NUM,UID,X,Y,Z,ptCtr.X, ptCtr.Y, ptCtr.Z]
#
#
#        if rs.IsTextDot(dot):
#            dotText = rs.TextDotText(dot)
#            newText = dotText.replace(key, replace)
#            dotPoint = rs.coerce3dpoint(rs.TextDotPoint(dot))
#            rs.TextDotText(dot, newText)


replaceTextDotsWithBlocks()