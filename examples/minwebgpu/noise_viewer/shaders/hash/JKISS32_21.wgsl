fn hash( p : vec2u ) -> u32
{
  var x = p.x;
  var y = p.y;
  var z = 345678912u;
  var w = 456789123u;
  var c = 0u;
  var t;
  y ^= ( y << 5u ); y ^= ( y >> 7u ); y ^= ( y << 22u );
  t = i32( z + w + c );
  z = w;
  c = u32( t < 0 );
  w = u32( t & 2147483647 );
  x += 1411392427u;
  return x + y + w;
}