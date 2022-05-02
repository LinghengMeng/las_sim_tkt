 
void oscOut_python() {

  OscMessage unitActuatorIntensities = new OscMessage("/4D/TRIAD1/UNIT1/INTENSITIES");
  
  int totalSymposiumVertices  = symposiumUnitInfo.length * symposiumUnitVertexCount;
  int totalSphereUnitVertices = sphereUnitInfo.length * sphereUnitVertexCount;

  for (int i=0; i<actuatorSystem.actuators.size(); i++) {
    
   //  println(i + ": -------");

    if (i < totalSymposiumVertices) {  // these are for the symposium units

      // SENDING SYMPOSIUM UNITS TO PYTHON

      int triadIndex = int(symposiumUnitInfo[i/symposiumUnitVertexCount][0]);
      int unitIndex = int(symposiumUnitInfo[i/symposiumUnitVertexCount][1]);

      if (i%symposiumUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/TRIAD"+triadIndex+"/UNIT"+unitIndex+"/INTENSITIES");
      }

      unitActuatorIntensities.add(int(actuatorSystem.actuators.get(i).intensity*255));

      if (i%symposiumUnitVertexCount==symposiumUnitVertexCount-1) {
        
        // pad with two more values, to make all messages have six actuator values.
        unitActuatorIntensities.add(0);
        unitActuatorIntensities.add(0);
        
       //  unitActuatorIntensities.printData();
        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
      }
      
    } else if(i < (totalSymposiumVertices + totalSphereUnitVertices) ) {    // these should be the old spunits


      // SENDING SPHERE UNITS TO PYTHON
      
      
      int triadIndex = int(sphereUnitInfo[(i-totalSymposiumVertices)/sphereUnitVertexCount][0]);
      int unitIndex =  int(sphereUnitInfo[(i-totalSymposiumVertices)/sphereUnitVertexCount][1]);

      if (i%sphereUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/TRIAD"+triadIndex+"/UNIT"+unitIndex+"/INTENSITIES");
      }

      unitActuatorIntensities.add(int(actuatorSystem.actuators.get(i).intensity*255));

      if (i%sphereUnitVertexCount==sphereUnitVertexCount-1) {
       // unitActuatorIntensities.printData();

        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
      }
    } else {   // these should be the RSs
      
      
         // SENDING SPHERE RS UNITS TO PYTHON
      
      
      int triadIndex = int(sphereRSUnitInfo[(i-(totalSymposiumVertices+totalSphereUnitVertices))/sphereUnitVertexCount][0]);
      int unitIndex =  int(sphereRSUnitInfo[(i-(totalSymposiumVertices+totalSphereUnitVertices))/sphereUnitVertexCount][1]);

      if (i%sphereRSUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/TRIAD"+triadIndex+"/UNIT"+unitIndex+"/INTENSITIES");
      }

      unitActuatorIntensities.add(int(actuatorSystem.actuators.get(i).intensity*255));

      if (i%sphereRSUnitVertexCount==sphereRSUnitVertexCount-1) {
       // unitActuatorIntensities.printData();

        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
      }
      
      
    }
  }
}




void oscOut_processing() {
  OscMessage unitActuatorIntensities = new OscMessage("/4D/INTENSITIES/");

  int totalSymposiumVertices  = symposiumUnitInfo.length * symposiumUnitVertexCount;
  int totalSphereUnitVertices = sphereUnitInfo.length * sphereUnitVertexCount;

  
  String my_address = FOUR_D_ENGINE.address();

  /// output Symposium messsages

  int message_data_index = 0;
  String intensities_message_data[] = { "", "", "", "", "", "", "", 
    "", "", "", "", "", "", "", 
    "", "", "", "", "", "", ""  } ;   /// max possible lenghth of an intensities string


  for (int i=0; i<actuatorSystem.actuators.size(); i++) {

    if (i < totalSymposiumVertices) {  // these are for the symposium units

      // SENDING SYMPOSIUM UNITS TO PROCESSING

      int triadIndex = int(symposiumUnitInfo[i/symposiumUnitVertexCount][0]);
      int unitIndex  = int(symposiumUnitInfo[i/symposiumUnitVertexCount][1]);

      if (i % symposiumUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/INTENSITIES/"+my_address+"/"+triadIndex+"-"+unitIndex );
        message_data_index = 0;
      }

      intensities_message_data[message_data_index] = Integer.toString(int(actuatorSystem.actuators.get(i).intensity*255));
      println(symposiumUnitVertexCount + " vs. " + i + " ("+  i/symposiumUnitVertexCount +") -  mdi " + message_data_index + ": " + intensities_message_data[message_data_index]);
      message_data_index++ ;

      if (i % symposiumUnitVertexCount==symposiumUnitVertexCount-1) {
        //   println("EOM");
        intensities_message_data[message_data_index] = "EOM"; 
       //  println(intensities_message_data);

        unitActuatorIntensities.add(intensities_message_data);
        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
      }
    } else if(i < (totalSymposiumVertices + totalSphereUnitVertices) ) {    // these should be the old spunits


      // SENDING SPHERE UNITS TO PROCESSING

      int triadIndex = int(sphereUnitInfo[(i-symposiumUnitInfo.length * symposiumUnitVertexCount)/sphereUnitVertexCount][0]);
      int unitIndex =  int(sphereUnitInfo[(i-symposiumUnitInfo.length * symposiumUnitVertexCount)/sphereUnitVertexCount][1]);

      if (i%sphereUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/INTENSITIES/"+my_address+"/"+triadIndex+"-"+unitIndex );
        message_data_index = 0;
      }


      intensities_message_data[message_data_index] = Integer.toString(int(actuatorSystem.actuators.get(i).intensity*255));
      println(sphereUnitVertexCount + " vs. " + i + " ("+  (i-symposiumUnitInfo.length * symposiumUnitVertexCount)/sphereUnitVertexCount +") -  mdi " + message_data_index + ": " + intensities_message_data[message_data_index]);
      message_data_index++ ;


      if (i % sphereUnitVertexCount==sphereUnitVertexCount-1) {
        //   println("EOM");
        intensities_message_data[message_data_index] = "EOM"; 
       // println(intensities_message_data);

        unitActuatorIntensities.add(intensities_message_data);
        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
      }
    } else {   // these should be the RSs
      
      
         // SENDING SPHERE RS UNITS TO PROCESSING
      
      
      int triadIndex = int(sphereRSUnitInfo[(i-(totalSymposiumVertices+totalSphereUnitVertices))/sphereUnitVertexCount][0]);
      int unitIndex =  int(sphereRSUnitInfo[(i-(totalSymposiumVertices+totalSphereUnitVertices))/sphereUnitVertexCount][1]);

      if (i%sphereRSUnitVertexCount==0) { 
        unitActuatorIntensities = new OscMessage("/4D/INTENSITIES/"+my_address+"/"+triadIndex+"-"+unitIndex );
        message_data_index = 0;
      }

      intensities_message_data[message_data_index] = Integer.toString(int(actuatorSystem.actuators.get(i).intensity*255));
      message_data_index++ ;


      if (i%sphereRSUnitVertexCount==sphereUnitVertexCount-1) {
         //   println("EOM");
        intensities_message_data[message_data_index] = "EOM"; 
       // println(intensities_message_data);

        unitActuatorIntensities.add(intensities_message_data);
        oscar.send(unitActuatorIntensities, MASTER_LAPTOP);
     }
      
      
    }
  }
}

// 
