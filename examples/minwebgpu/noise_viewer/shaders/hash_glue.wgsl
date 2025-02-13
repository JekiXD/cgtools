fn intTofloat( v : u32 ) -> f32
{
  let f = ( v & 0x007fffffu ) | 0x3f800000u;
  return bitcast< f32 >( f ) - 1.0;
}

fn get_hash( p_in : vec2f ) -> f32
{
  let p = vec2u( p_in );
  if( uniforms.linear_hash > 0 )
  {
    let r = hash( p.x * 19 + p.y * 47 );
    return intTofloat( r );
  }
  else
  {
    let r = hash( hash( p.x ) + p.y );
    return intTofloat( r );
  }
}