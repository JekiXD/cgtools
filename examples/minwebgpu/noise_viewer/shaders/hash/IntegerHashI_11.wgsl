fn hash( n_in : u32 ) -> u32
{
  var n = n_in;
  n = ( n << 13u ) ^ n;
  n = n * ( n * n * 15731u + 789221u ) + 1376312589u;
  return n;
}