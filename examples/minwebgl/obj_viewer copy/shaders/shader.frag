#version 300 es
precision highp float;

uniform vec3 eye;
uniform vec3 up;
uniform vec3 viewDir;
uniform vec2 resolution;

out vec4 frag_color;

float raytrace_plane
( 
  in vec3 ro, // Ray origin
  in vec3 rd, // Ray direction
  in vec3 normal, // Normal of the plane
  in vec3 p0 // Any point on the plane
)
{
  // If this equals 0.0, then the line is parallel to the plane
  float RdotN = dot( rd, normal );
  if( RdotN == 0.0 ) { return -1.0; }

  float t = dot( ( p0 - ro ), normal ) / RdotN;
  return t;
}

vec2 raytrace_box
(
  in vec3 ro, 
  in vec3 rd, 
  out vec3 normal, // Normal at the hit point
  in vec3 box_dimension,
  in bool entering
) 
{
  // Having an equation ro + t * rd, we calculate an intersection `t` with 3 planes : xy, xz, and yz.
  // we calculate `t`, such that our ray hits the planes xy, xz, yz.
  // The result for each plane is stored in z, y, x coordinates of the `t` variable respectively.
  vec3 dr = 1.0 / rd;
  vec3 t = ro * dr;
  // Now we need to offset the `t` to hit planes that build the box.
  // If we take a point in the corner of the box and calculate the distance needed to travel from that corner
  // to all three planes, we can then take that distance and subtruct/add to our `t`, to get the proper hit value.
  vec3 dt = box_dimension * abs( dr );
  
  // Planes facing us are closer, so we need to subtruct
  vec3 pin = - dt - t;
  // Planes behind the front planes are farther, so we need to add
  vec3 pout =  dt - t;

  // From the distances to all the front and back faces, we find faces of the box that are actually hit by the ray
  float tin = max( pin.x, max( pin.y, pin.z ) );
  float tout = min( pout.x, min( pout.y, pout.z ) );

  // Ray is outside of the box
  if( tin > tout )
  { 
    return vec2( -1.0 );
  }

  // Calculate the normal
  if( entering )
  {
    normal = -sign( rd ) * step( pin.zxy, pin.xyz ) * step( pin.yzx, pin.xyz );
  } 
  else 
  {
    normal = sign (rd ) * step( pout.xyz, pout.zxy ) * step( pout.xyz, pout.yzx );
  }

  return vec2( tin, tout );
}

const vec3 BOX_SIZE = vec3( 1.0, 1.0 / 2.0, 1.0 ) * 1.0; 
const int NUM_STEPS = 64;

float remap
( 
  in float t_min_in, 
  in float t_max_in, 
  in float t_min_out, 
  in float t_max_out, 
  in float v 
)
{
  float k = ( v - t_min_in ) / ( t_max_in - t_min_in );
  return mix( t_min_out, t_max_out, k );
}

float sin_sum_abs( vec2 p )
{
  return abs( sin( p.y ) + cos( p.x ) );
}

float sin_sum( vec2 p )
{
  return sin( p.y ) + cos( p.x );
}

vec3 draw_2d( vec3 ro, vec3 rd )
{
  float nudge = 0.9; // size of perpendicular vector
  float normalizer = 1.0 / sqrt( 1.0 + nudge * nudge ); // 
  float t = raytrace_plane( ro, rd, vec3( 0.0, 1.0, 0.0 ), vec3( 0.0 ) );
  vec3 color = vec3( 0.0 );
  if( t >= 0.0 )
  {
    vec3 p = ro + t * rd;

    {
      vec3 p = p + vec3( 1.0, 0.0, 0.0 ) * 1.0;
      if( all( lessThanEqual( abs( p.xz ), vec2( 1.0 ) ) ) )
      {
        p.xz += vec2( p.z, -p.x ) * nudge;
        p.xz *= normalizer;
        
        // p.xy += vec2( p.y, -p.x ) * nudge;
        // p.xy *= normalizer;
        // vec2 tmp = vec2( p.z, -p.x ) * nudge;
        // p += vec3( tmp.x, 0.0, tmp.y );
        // p *= vec3( normalizer, 1.0, normalizer );
        
        float v = sin_sum_abs( p.xz * 10.0 );
        v = remap( 0.0, 2.0, 0.0, 1.0, v );
        color += vec3( v );
      }
    }

    {
      vec3 p = p + vec3( 3.2, 0.0, 0.0 );
      if( all( lessThanEqual( abs( p.xz ), vec2( 1.0 ) ) ) )
      { 
        p.xy += vec2( p.y, -p.x ) * nudge;
        p.xy *= normalizer;
        
        float v = sin_sum_abs( p.xz * 10.0 );
        v = remap( 0.0, 2.0, 0.0, 1.0, v );
        color += vec3( v );
      }
    }

    {
      vec3 p = p + vec3( 3.2, 0.0, 2.0 );
      if( all( lessThanEqual( abs( p.xz ), vec2( 1.0 ) ) ) )
      { 
        p.yz += vec2( p.z, -p.x ) * nudge;
        p.yz *= normalizer;
        
        float v = sin_sum_abs( p.xz * 10.0 );
        v = remap( 0.0, 2.0, 0.0, 1.0, v );
        color += vec3( v );
      }
    }

    {
      vec3 p = p - vec3( 1.0, 0.0, 0.0 ) * 1.2;
      if( all( lessThanEqual( abs( p.xz ), vec2( 1.0 ) ) ) )
      {
        float v = sin_sum( p.xz * 10.0 );
        v = remap( -2.0, 2.0, 0.0, 1.0, v );
        color += vec3( v );
      }
    }
     //color = vec3( 1.0 );
  }
  return color;
}

vec3 draw_3d( vec3 ro, vec3 rd, vec3 vx )
{
  vec3 color = vec3( 0.0 );
  float nudge = 0.9; // size of perpendicular vector
  float normalizer = 1.0 / sqrt( 1.0 + nudge * nudge ); // 
  {
    vec3 boxNormal;
    vec2 tv = raytrace_box( ro, rd, boxNormal, BOX_SIZE, true );

    if( any( notEqual( tv, vec2( -1.0 ) ) ) )
    {
      tv.x = max( tv.x, 0.0 );
      vec3 p;
      float step_size = ( tv.y - tv.x ) /  float( NUM_STEPS ) ;
      float t = tv.y;
      for( int i = 0; i < NUM_STEPS; i++ )
      {
        p = ro + rd * t; 
        p += vec3( vec2( p.y, -p.x ) * nudge, 0.0 );
        p *= vec3( normalizer, normalizer, 1.0 );

        // vec2 tmp = vec2( p.z, -p.x ) * nudge;
        // p += vec3( tmp.x, 0.0, tmp.y );
        // p *= vec3( normalizer, 1.0, normalizer );

        float v = sin_sum_abs( p.xz * 10.0 );
        v = remap( 0.0, 2.0, 0.0, 1.0, v );
        color += v * vec3( 1.0 ) / float( NUM_STEPS );

        t -= step_size;
      }
    }
  }

  return color;
}


void main()
{
  vec3 vz = normalize( viewDir );
  vec3 vy = normalize( up );
  vec3 vx = normalize( cross( vz, vy ) );
  vy = normalize( cross( vx, vz ) );
  mat3 m = mat3( vx, vy, vz );


  vec3 ro = eye;
  vec3 rd = vec3( ( gl_FragCoord.xy * 2.0 - resolution.xy ) / resolution.x, 0.7 );
 // rd.x *= -1.0;
  rd = normalize( m * rd );
  vec3 color = vec3( 0.0, 0.0, 0.0 );
  color = draw_2d( ro, rd );
  //color = draw_3d( ro, rd, vx );


  frag_color = vec4( color, 1.0 );
}
