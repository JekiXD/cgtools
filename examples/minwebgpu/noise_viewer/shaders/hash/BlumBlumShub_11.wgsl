
fn hash( v_in : u32 ) -> u32
{
  var v = v_in;
  v = v % 65521u;
  v = ( v * v ) % 65521u;
  v = ( v * v ) % 65521u;
  return v; 
}