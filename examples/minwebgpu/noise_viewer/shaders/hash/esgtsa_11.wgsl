fn hash( s_in : u32 ) -> u32
{
  var s = s_in;
  s = ( s ^ 2747636419u ) * 2654435769u;
  s = ( s ^ ( s >> 16u ) ) * 2654435769u;
  s = ( s ^ ( s >> 16u ) ) * 2654435769u;
  return s; 
}