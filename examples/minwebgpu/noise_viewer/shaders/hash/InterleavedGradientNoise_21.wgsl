
fn hash( v : vec2f ) -> f32
{
  let magic = vec3f( 0.06711056, 0.00583715, 52.9829189 );
  return fract( magic.z * fract( dot( v, magic.xy ) ) ); 
}