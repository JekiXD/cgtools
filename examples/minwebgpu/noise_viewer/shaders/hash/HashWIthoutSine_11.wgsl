fn hash( p_in : f32 ) -> f32
{
  var p = p_in;
  p = fract( p * .1031 );
  p *= p + 33.33;
  p *= p + p;
  return fract( p );
}