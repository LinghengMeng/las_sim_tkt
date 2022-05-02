import rhinoscriptsyntax as rs
import Rhino.Geometry as rg
import csv

NODEID_DICTIONARY = {

    "TG:1" : {
        "HU:1" : 379773,
        "HU:2" : 432837,
        "HU:3" : 432834,
        "GN:1" : 393070
        }, # end TG:1

    "TG:2" : {
        "HU:1" : 379853,
        "HU:2" : 432785,
        "HU:3" : 432838,
        "GN:1" : 379756
        }, # end TG:2

    "TG:3" : {
        "HU:1" : 379768,
        "HU:2" : 362309,
        "HU:3" : 379763,
        "GN:1" : 435144
        }, # end TG:3

    "TG:4" : {
        "HU:1" : 379779,
        "HU:2" : 432835,
        "HU:3" : 607632,
        "GN:1" : 336690
        }, # end TG:4

    "TG:5" : {
        "HU:1" : 362312,
        "HU:2" : 379761,
        "HU:3" : 393069,
        "GN:1" : 432786
        }, # end TG:5

    "MG:2" : {
        "MU:1" : 379754,
        "MU:2" : 432792,
        "GN:1" : 362145
        }, # end MG:2

    "MG:3" : {
        "MU:1" : 379776,
        "MU:2" : 435151,
        "GN:1" : 393051
        }, # end MG:3
 
    "MG:5" : {
        "MU:1" : 379778,
        "MU:2" : 435146,
        "GN:1" : 379770
        }, # end MG:5

    "SR:1" : {
        "PF:1" : 335579,
        "F1:1" : 258613,
        "GN:1" : 432772
    }, # end SR:1

    "SR:2" : {
        "PF:1" : 393074,
        "F1:1" : 435162,
        "GN:1" : 379760
    }, # end SR:2
    
    "SR:3" : {
        "PF:1" : 432836,
        "F1:1" : 356656,
        "GN:1" : 336638
    }, # end SR:3
    
    "SR:4" : {
        "PF:1" : 608444,
        "F1:1" : 608441,
        "GN:1" : 608290
    }, # end SR:4
    
    "SR:5" : {
        "PF:1" : 607710,
        "F1:1" : 608465,
        "GN:1" : 607722
    }, # end SR:5

    "SR:6" : {
        "P2:1" : 362307
    }, # end SR:6

    "SR:7" : {
        "RH:1" : 432833,
        "RH:2" : 435168
    }, # end SR:7

    "NR:1" : {
        "PF:1" : 335639,  # secondary nest
        "F1:1" : 259304,
        "GN:1" : 245734
    }, # end NR:1

    "NR:2" : {
        "PF:1" : 608485,  # secondary nest
        "F1:1" : 432771,
        "GN:1" : 336652
    }, # end NR:2

    "NR:3" : {
        "P1:1" : 336617,
        "F2:1" : 336654,
        "F2:2" : 336654  # note, both F2s on one NC -mg
    },

    "NR:4" : {
        "PF:1" : 356569,  # secondary nest
        "F1:1" : 379775,
        "GN:1" : 393048
    }, # end NR:4

    "NR:5" : {
        "PF:1" : 336612,  # secondary nest
        "F1:1" : 607786,
        "GN:1" : 607769
    }, # end NR:5

    "NR:6" : {
        "PF:1" : 336633,  # secondary nest
        "F1:1" : 608321,
        "GN:1" : 607606
    }, # end NR:6

    "NR:7" : {
        "P1:1" : 432840,
        "F2:1" : 362340,
        "F2:2" : 362340    # note, both F2s on one NC -mg
        }, # end NR:7

    "NR:8" : {
        "PF:1" : 136306,  # secondary nest
        "F1:1" : 607814,
        "GN:1" : 608418
    }, # end NR:8

    "NR:9" : {
        "P2:1" : 608399
    }, # end NR:9

    "NR:10" : {
        "RH:1" : 248880,
        "RH:2" : 335496
    } # end NR:10
}

IP_DICTIONARY = {
    "TG" : 8,
    "MG" : 7,
    "NR" : 6,
    "SR" : 5,
    "IN" : 4
}

DEVICETYPE_DICTIONARY = {
    "MO" : "actuator",
    "MM" : "actuator",
    "RS" : "actuator",
    "GE" : "sensor",
    "IR" : "sensor",
    "SD" : "sensor",
    "DR" : "actuator",
    "WT" : "actuator",
    "SM" : "actuator",
    "PC" : "actuator",
    "OS" : "actuator"
    }


UID_DICTIONARY = {
    "HU" : {
        "MO" : {
            1 : 21,
            2 : 26,
            3 : 31,
            4 : 23,
            5 : 29,
            6 : 30
            },
        "DR" : {
            1 : 25,
            2 : 32,
            3 : 6
            },
        "SD" : {
            1 : 16
            },
        "GE" : {
            1 : 18
            }
        },
    # end HU


    "MU" : {
        "MM" : {
            1 : 5,
            2 : 20,
            3 : 16,
            4 : 17,
            5 : 6,
            6 : 21,
            7 : 26,
            8 : 31,
            9 : 22,
            10 : 23,
            11 : 29,
            12 : 30
            },
        "DR" : {
            1 : 3,
            2 : 25,
            3 : 9
            },
        "GE" : {
            1 : 18
            }
        },
    # end MU


    "RH" : {
        "RS" : {
            1 : 3,
            2 : 4,
            3 : 5,
            4 : 20,
            5 : 25,
            6 : 32,
            7 : 6,
            8 : 21,
            9 : 9,
            10 : 10
            }
        },
    # end RH


    "P2" : {
        "PC" : {
            1 : 3,
            2 : 4,
            3 : 5,
            4 : 20,
            5 : 25,
            6 : 32,
            7 : 6,
            8 : 21,
            9 : 9,
            10 : 10
            }
        },
    # end P2


    "F1" : {
        "RS" : {
            1 : 3,
            2 : 4,
            3 : 5,
            4 : 25,
            5 : 32,
            6 : 6
            },
        "MO" : {
            1 : 20,
            2 : 16,
            3 : 17,
            4 : 21,
            5 : 26,
            6 : 31
            },
        "SD" : {
            1 : 29
            },
        "GE" : {
            1 : 18
            }
        },
    # end F1

    "F2" : {
        "RS" : {
            1 : 3,
            2 : 4,
            3 : 5,
            4 : 25,
            5 : 32,
            6 : 6
            },
        "MO" : {
            1 : 20,
            2 : 16,
            3 : 17,
            4 : 21,
            5 : 26,
            6 : 31
            }
        },
    # end F2

    "PF" : {
        "RS" : {
            1 : 9,
            2 : 10,
            3 : 22
            },
        "MO" : {
            1 : 23,
            2 : 29,
            3 : 30
            },
        "SM" : {
            1 : 32,
            2 : 6,
            3 : 21
            },
        "PC" : {
            1 : 25
            },
        "IR" : {
            1 : 17
            }
        },
    # end PF

    "P1" : {
        "SM" : {
            1 : 32,
            2 : 6,
            3 : 21
            },
        "PC" : {
            1 : 25
            },
        "IR" : {
            1 : 17
            }
        },
    # end P1

    "GN" : {
        "GE" : {
            1 : 18
            }
        }
    # end GN
    }

def UID_LOOKUP(_NODETYPE, _DEVICE, _NUM):
    if _NODETYPE in UID_DICTIONARY:
        if _DEVICE in UID_DICTIONARY[_NODETYPE]:
            if _NUM in UID_DICTIONARY[_NODETYPE][_DEVICE]:
                return UID_DICTIONARY[_NODETYPE][_DEVICE][_NUM]
    return "--"


def NODEID_LOOKUP(_GROUPNUM, _NODENUM):
    if _GROUPNUM in NODEID_DICTIONARY:
        if _NODENUM in NODEID_DICTIONARY[_GROUPNUM]:
                return NODEID_DICTIONARY[_GROUPNUM][_NODENUM]
    return "999999"

#centerDot = rs.GetObject("Select Center Point", 8192)
ptCtr = rg.Point3d(0,0,0) #rs.TextDotPoint(centerDot)
dotObjects = rs.GetObjects("Select Text Dots", 8192) # input your text dots

CONTROL_IP = "172.23.1.99"

# with open("C:\\Users\\timothyb\\Desktop\\asdf-2.csv",'wb') as f:
with open("/Users/Snickersnack/Dropbox/PBAI/Code/Processing-Simulator/Device_Locator_CSV_Python/DL_output.csv",'wb') as f:
    writer = csv.writer(f, delimiter =',')
    writer.writerow(["GROUP", "DEVICE", "NUM", "UID", "X", "Y", "Z", "T_X", "T_Y", "T_Z", "PI IP", "NODE ID", "DEVICE_TYPE", "CONFIG", "INSTALLED", "NODE_TYPE", "CONTROL IP"])
    for dotObject in dotObjects: # for each text dot, i.e. each object in the collection
        text = rs.TextDotText(dotObject)
        point = rs.TextDotPoint(dotObject)
        splits = text.split(':')
        if len(splits) > 1:
            GROUP = splits[0] + ":" + splits[1] + ":" + splits[2] + ":" + splits[3]
            DEVICE = splits[4]
            NODETYPE = splits[2]
            if len(splits) < 6:
                NUM = "--"
                UID = "--"
            else:
                NUM = int(splits[5])
                UID = UID_LOOKUP(NODETYPE, DEVICE, NUM)
            X = point.X
            Y = point.Y
            Z = point.Z
            line = [GROUP,DEVICE,NUM,UID,"{:.4f}".format(X),"{:.4f}".format(Y),"{:.4f}".format(Z),"{:.4f}".format(ptCtr.X), "{:.4f}".format(ptCtr.Y), "{:.4f}".format(ptCtr.Z), "172.23.1." + str(IP_DICTIONARY[splits[0]]) + str(int(splits[1]) % 10), NODEID_LOOKUP(splits[0] + ":" + splits[1], splits[2] + ":" + splits[3]), DEVICETYPE_DICTIONARY.get(DEVICE, "--"), "", "", NODETYPE, CONTROL_IP]
            writer.writerow(line)
