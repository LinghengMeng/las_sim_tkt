

PVector[] polygon(int _vertexCount, float _width, float _height) {
  PVector[] vertices = new PVector[_vertexCount];
  for (int i=0; i<_vertexCount; i++) { 
    vertices[i] = new PVector();
    vertices[i].x = sin(TWO_PI/_vertexCount*i+PI)*_width;
    vertices[i].y = cos(TWO_PI/_vertexCount*i+PI)*_height;
  }
  return vertices;
}



PVector symposiumVertexPoint(int _vertexCount, float _width, float _height, int _index) {
 
  
  PVector vertex = new PVector();
  
   switch(_index) {
     
    case 0:
    vertex.x = _height;
    vertex.y = _width/2 * 0;
    vertex.z = 0.0;
    
    break;
    
    case 1: 
    vertex.x = _height;
    vertex.y = _width/2 * 1;
    vertex.z = 0.0; 
    break;
    
    case 2:  // top rebel star
    vertex.x = _height +_width/10;
    vertex.y = _width/2 * 1; 
    vertex.z = 0.0;
    break;

    case 3:
    vertex.x = _height;
    vertex.y = _width/2 * 2;
    vertex.z = 0.0;
    break;
 
    default:
    break;
   }
  
 
  return vertex;
  
  
}

PVector polygonVertexPoint(int _vertexCount, float _width, float _height, int _index) {
  PVector vertex = new PVector();
  vertex.x = sin(TWO_PI/_vertexCount*_index+PI)*_width;
  vertex.y = cos(TWO_PI/_vertexCount*_index+PI)*_height;
  return vertex;
}

PVector polygonRSVertexPoint(int _vertexCount, float _width, float _height, int _index) {
  int i = _index/2;
  _index = _index %2;
  PVector vertex = new PVector();
  vertex.x = sin( (PI/6) + 2*TWO_PI/_vertexCount* (i+PI) )*_width    + 0.05*_index ;
  vertex.y = cos( (PI/6) + 2*TWO_PI/_vertexCount* (i+PI) )*_height;
  return vertex;
}



PVector convertVectorToPixelSpace(PVector input) {
  PVector coordinates = input.copy();
  return coordinates.mult(100);
}



PVector[] convertVectorToPixelSpaceArray(PVector[] input) {
  PVector[] coordinates = new PVector[input.length];
  for (int i=0; i<input.length; i++) {
    coordinates[i] = input[i].copy().mult(100);
  }
  return coordinates;
}
