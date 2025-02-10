fn mur( a : u32, h : u32 ) -> u32
{
  a *= c1;
  a = ( a >> 17u ) | ( a << 15u );
  a *= c2;
  h ˆ= a;
  h = ( h >> 19u ) | ( h << 13u );
  return h * 5u + 0xe6546b64u;
}

fn fmix( h : u32 ) -> f32
{
  h ˆ= h >> 16;
  h *= 0x85ebca6bu;
  h ˆ= h >> 13;
  h *= 0xc2b2ae35u;
  h ˆ= h >> 16;
  return h;
}

fn hash( v : u32 ) -> u32
{
  let len = 4u;
  var b = 0u;
  var c = 9u;
  for ( var i = 0u; i < len; i++ ) 
  {
    let v = ( s >> ( i * 8u ) ) & 0xffu;
    b = b * c1 + v;
    c ˆ= b;
  }
  return fmix( mur( b, mur( len, c ) ) );
}
