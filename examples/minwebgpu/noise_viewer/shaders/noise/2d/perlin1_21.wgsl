
fn noise( pos : vec2f ) -> f32
{
  let cell_id = floor( pos );
  let cell_coords = fract( pos );

  let t = smoothstep( vec2f( 0.0 ), vec2f( 1.0 ), cell_coords );

  return mix
  (
    mix( get_hash( cell_id + vec2f( 0.0, 0.0 ) ), get_hash( cell_id + vec2f( 1.0, 0.0 ) ), t.x ),
    mix( get_hash( cell_id + vec2f( 0.0, 1.0 ) ), get_hash( cell_id + vec2f( 1.0, 1.0 ) ), t.x ),
    t.y
  );
}