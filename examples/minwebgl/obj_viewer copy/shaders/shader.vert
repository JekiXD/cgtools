#version 300 es
#pragma vscode_glsllint_stage : vert

const vec2 points[ 4 ] = vec2[]
(
  vec2( -1.0, 1.0 ),    // Top-left vertex
  vec2( 1.0, 1.0 ),     // Top-right vertex
  vec2( -1.0, -1.0 ),   // Bottom-left vertex
  vec2( 1.0, -1.0 )     // Bottom-right vertex
);


void main()
{
  vec2 position = points[ gl_VertexID ];
  gl_Position = vec4( position, 0.0, 1.0 );
}