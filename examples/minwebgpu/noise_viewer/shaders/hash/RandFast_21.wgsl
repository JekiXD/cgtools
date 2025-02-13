fn hash( v_in : vec2f ) -> f32
{
  let v = ( 1. / 4320. ) * v_in + vec2f( 0.25,0. );
  let state = fract( dot( v * v, vec2f( 3571.0 ) ) );
  return fract( state * state * ( 3571. * 2. ) );
}