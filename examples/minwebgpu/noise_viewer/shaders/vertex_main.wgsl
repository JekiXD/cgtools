struct VSOut
{
  @builtin( position ) pos : vec4f,
  @location( 0 ) uv : vec2f
}

@vertex
fn vs_main( @builtin( vertex_index ) id : u32 ) -> VSOut
{
  // 0 - x 0 y 0
  // 1 - x 0 y 1
  // 2 - x 1 y 0
  let x = f32( id / 2 );
  let y = f32( id % 2 );

  let pos = vec2f( -1.0 ) + 4.0 * vec2f( x, y );
  let uv = 2.0 * vec2( x,  y );

  var out : VSOut;
  out.pos = vec4f( pos, 0.0, 1.0 );
  out.uv = uv;
  var positions = array< vec3f, 3 >
  (
    vec3f( -0.5, -0.5, 0.0 ),
    vec3f( 0.0, 0.5, 0.0 ),
    vec3f( 0.5, -0.5, 0.0 ),
  );

  return out;
}