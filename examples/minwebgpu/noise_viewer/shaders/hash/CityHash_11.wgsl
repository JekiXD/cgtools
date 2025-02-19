fn mur( a_in : u32, h_in : u32 ) -> u32
{
  var a = a_in;
  var h = h_in;
  a *= c1;
  a = ( a >> 17u ) | ( a << 15u );
  a *= c2;
  h ^= a;
  h = ( h >> 19u ) | ( h << 13u );
  return h * 5u + 0xe6546b64u;
}

fn fmix( h_in : u32 ) -> u32
{
  var h = h_in;
  h ^= h >> 16;
  h *= 0x85ebca6bu;
  h ^= h >> 13;
  h *= 0xc2b2ae35u;
  h ^= h >> 16;
  return h;
}

fn hash( s : u32 ) -> u32
{
  let len = 4u;
  var b = 0u;
  var c = 9u;
  for ( var i = 0u; i < len; i++ ) 
  {
    let v = ( s >> ( i * 8u ) ) & 0xffu;
    b = b * c1 + v;
    c ^= b;
  }
  return fmix( mur( b, mur( len, c ) ) );
}
