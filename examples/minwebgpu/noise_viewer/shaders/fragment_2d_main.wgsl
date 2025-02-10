struct VSOut
{
  @builtin( position ) pos : vec4f,
  @location( 0 ) uv : vec2f
}

@fragment
fn fs_main( in : VSOut ) -> @location( 0 ) vec4f
{
  var color = vec3f( noise( in.uv * 100.0 ) );
  return vec4f( color, 1.0 );
}

fn hash( co : vec2f ) -> f32 {
  return fract( sin( dot( co, vec2f( 12.9898, 78.233 ) ) ) * 43758.5453 );
}

fn noise( pos : vec2f ) -> f32
{
  let cell_id = floor( pos );
  let cell_coords = fract( pos );

  let t = smoothstep( vec2f( 0.0 ), vec2f( 1.0 ), cell_coords );

  return mix
  (
    mix( hash( cell_id + vec2f( 0.0, 0.0 ) ), hash( cell_id + vec2f( 1.0, 0.0 ) ), t.x ),
    mix( hash( cell_id + vec2f( 0.0, 1.0 ) ), hash( cell_id + vec2f( 1.0, 1.0 ) ), t.x ),
    t.y
  );
}