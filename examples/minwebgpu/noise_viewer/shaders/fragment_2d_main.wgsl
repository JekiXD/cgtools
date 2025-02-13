struct Uniforms
{
  resolution : vec2f,
  linear_hash : i32
}

@group( 0 ) @binding( 0 ) var< uniform > uniforms : Uniforms;

struct VSOut
{
  @builtin( position ) pos : vec4f,
  @location( 0 ) uv : vec2f
}

@fragment
fn fs_main( in : VSOut ) -> @location( 0 ) vec4f
{
  var uv = in.pos.xy / uniforms.resolution.x;
  var color = vec3( 0.0 );
  color = vec3( noise( uv * 10.0 ) );

  return vec4f( color, 1.0 );
}
