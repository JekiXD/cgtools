
fn hash( v : u32 ) -> u32
{
  v = v % 65521u;
  v = ( v * v ) % 65521u;
  v = ( v * v ) % 65521u;
  return v; 
}