struct VSOut
{
  @builtin( position ) pos : vec4f,
}

@vertex
fn vs_main( @builtin( vertex_index ) id : u32 ) -> VSOut
{
  var positions = array< vec3f, 4 >
  (
    vec3f( -1.0, -1.0, 0.0 ),
    vec3f( 1.0, -1.0, 0.0 ),
    vec3f( -1.0, 1.0, 0.0 ),
    vec3f( 1.0, 1.0, 0.0 ),
  );

  var out : VSOut;
  out.pos = vec4f( positions[ id ], 1.0 );

  return out;
}

struct Uniforms
{
  eye : vec3f,
  view_dir: vec3f,
  up : vec3f,
  resolution : vec2f,
  time : f32
}

@group( 0 ) @binding( 0 ) var< uniform > u : Uniforms;

const BOX_SIZE : vec3f = vec3f( 1.0, 1.0, 1.0 );
// Refractive index of the air
const airRI : f32 = 1.0;
// Refractive index of the box( water )
const boxRI : f32 = 1.33;
// Index of refraction Air to Box
const iorAtoB : f32 = airRI / boxRI;
// Index of refraction Box to Air
const iorBtoA : f32 = boxRI / airRI;
const F0 : vec3f = vec3f( pow( abs( ( boxRI - airRI ) ) / ( boxRI + airRI ), 2.0 ) );
const COLOR_ABSORPTION : vec3f = vec3f( 0.9 );
//const COLOR_ABSORPTION : vec3f = vec3f( 0.5, 0.5, 0.9 );
const NUM_REFLECTIONS : i32 = 5;
const BOX_DIMENSIONS : vec3f = vec3f( 0.5, 1.0, 0.5 );
// Distance to the edges
const BOX_DTE : vec3f = vec3f( length( BOX_DIMENSIONS.xz ), length( BOX_DIMENSIONS.xy ), length( BOX_DIMENSIONS.yz ) );
const CRITICAL_ANGLE_ATOB : f32 = sqrt( max( 0.0, 1.0 - iorBtoA * iorBtoA ) );
const CRITICAL_ANGLE_BTOA : f32 = sqrt( max( 0.0, 1.0 - iorAtoB * iorAtoB ) );
const LIGHT_POWER : f32 = 8.0;
const BOX_EDGE_COLOR : vec3f = vec3f( 0.0 );
const MOON_LIGHT_DIR : vec3f = normalize( vec3f( -1.0, 1.0, -1.0 ) );

@fragment
fn fs_main( in : VSOut ) -> @location( 0 ) vec4f
{
  // Ray origin
  let ro = u.eye;
  var light_source = normalize( vec3f( -1.0, 1.0, -1.0 ) ) * vec3f( 3.75, 2.0, 3.75 );

  // Orthonormal vectors of the view transformation
  let vz = normalize( u.view_dir );
  var vy = normalize( u.up );
  let vx = normalize( cross( vz, vy ) );
  vy = normalize( cross( vx, vz ) );

  // Ray direction u.resolution.y / u.resolution.x
  var uv = ( in.pos.xy * 2.0 - u.resolution ) / u.resolution;
  uv = uv * 0.5 + 0.5;

  var rd = vec3f( ( in.pos.xy * 2.0 - u.resolution ) / u.resolution.x, 0.7 );
  rd.y *= -1.0;
  rd = normalize( vx * rd.x + vy * rd.y + vz * rd.z );

  var final_color = vec3f( 0.0 );
  final_color = draw_background( ro, rd, light_source );
  //draw_patch( ro + vec3f( 0.0, 0.0, 0.0 ), rd, &final_color );

  var box_normal : vec3f;
  let box_t = raytrace_box( ro, rd, &box_normal, true );

  if box_t > 0.0
  {
    var ro = ro + box_t * rd;

    let F = freshel( -rd, box_normal, F0, CRITICAL_ANGLE_ATOB );
    var refractedRD = refract( rd, box_normal, iorAtoB );
    let reflectedRD = normalize( reflect( rd, box_normal ) );

    if length( refractedRD ) > 0.0
    {
      refractedRD = normalize( refractedRD );
      let insides_color = draw_insides( ro, refractedRD, light_source );
      final_color += ( 1.0 - F ) * insides_color;
    }

    let refl_color = draw_background( ro, reflectedRD, light_source );
    final_color += F * refl_color;

    let edge_t = smooth_box_edge( ro );
    final_color = mix( final_color, BOX_EDGE_COLOR, edge_t ) ;
  }

  //return vec4f( aces_tonemap( final_color ), 1.0 );
  return vec4f( final_color, 1.0 );
}

// Paint the edges in black with a little blur at transition
fn smooth_box_edge( ro : vec3f ) -> f32
{
  let edge_blur = smoothstep
  ( 
    BOX_DTE - vec3f( 0.02 ), 
    BOX_DTE, 
    vec3f( length( ro.xz ), length( ro.xy ), length( ro.yz ) ) 
  );

  return max( edge_blur.x, max( edge_blur.y, edge_blur.z ) );
}

//https://en.wikipedia.org/wiki/Line%E2%80%93plane_intersection
fn raytrace_plane
( 
  ro_in : vec3f, // Ray origin
  rd_in : vec3f, // Ray direction
  normal : vec3f, // Normal of the plane
  p0 : vec3f // Any point on the plane
) -> f32
{
  // If this equals 0.0, then the line is parallel to the plane
  let RdotN = dot( rd_in, normal );
  if RdotN == 0.0 { return -1.0; }

  let t = dot( ( p0 - ro_in ), normal ) / RdotN;
  return t;
}

fn draw_background
(
  ro_in : vec3f,
  rd_in : vec3f,
  light_source : vec3f
) -> vec3f
{
  var final_color = vec3f( 0.0 );
  let plane_size = 5.0;//10.0;
  let blur_radius = 8.0;
  let plane_normal = vec3f( 0.0, 1.0, 0.0 ); // Normal of the plane
  let p0 = vec3f( 0.0, -1.01, 0.0 ); // Any point on the plane

  if rd_in.y > 0.01
  {
    final_color += draw_stars( rd_in );
  }

  let plane_t = raytrace_plane( ro_in, rd_in, plane_normal, p0 );

  if plane_t > 0.0
  {
    let plane_hit = ro_in + plane_t * rd_in;
    let uv = abs( plane_hit.xz );
    if all( uv <= vec2f( plane_size ) )
    {
      let r = length( light_source - plane_hit );
      let attenuation = LIGHT_POWER / ( r * r );

      let light_dir = normalize( light_source - plane_hit );
      let LdotN = saturate( dot( light_dir, plane_normal ) );
      let H = normalize( light_dir - rd_in );
      let phong_value = pow( saturate( dot( plane_normal, H ) ), 16.0 ) * 0.1;

      var diff_color : vec3f;
      {
        let len = length( uv );
        var f : f32; 
        if i32( len ) % 2 == 0 { f = fract( len ); } else { f = 1.0 - fract( len ); }

        diff_color = mix( vec3f( 0.5 ), vec3f( 1.0 ), smoothstep( 0.0, 1.0, f ) );
      }
      var plane_color = ( LdotN * diff_color + phong_value );
      plane_color *= attenuation; 

      final_color = mix
      ( 
        plane_color, 
        final_color, 
        smoothstep
        ( 
          blur_radius - 1.5,
          blur_radius,
          length( uv )
        ) 
      );
    }
    else
    {
      let sea_color = draw_sea( plane_hit, rd_in );

      // let reflectedRD = normalize( reflect( rd_in, vec3f( 0.0, 1.0, 0.0 ) ) );
      // let F0 = vec3f( 0.02 );
      // let critical_angle = 0.0;
      // let F = freshel( -reflectedRD, plane_normal, F0, critical_angle );

      // let stars = draw_stars( reflectedRD );
      // final_color = F * stars;
      final_color = sea_color;
    }
  }

  return final_color;
}

fn draw_insides
(
  ro_in : vec3f,
  rd_in : vec3f,
  light_source : vec3f
) -> vec3f
{
  var distance_traveled = 1.0;
  var final_color = vec3f( 0.0 );
  var prev_ro = ro_in;
  var prev_rd = rd_in;
  var attenuation = vec3f( 1.0 );
  for( var i = 0; i < NUM_REFLECTIONS; i++ )
  {
    var box_normal : vec3f;
    let box_t = raytrace_box( prev_ro, prev_rd, &box_normal, false );

    var new_ro = prev_ro + box_t * prev_rd;
    distance_traveled += length( prev_ro - new_ro );

    let F = freshel( prev_rd, box_normal, F0, CRITICAL_ANGLE_BTOA );
    let reflectedRD = normalize( reflect( prev_rd, -box_normal ) );
    let refractedRD = refract( prev_rd, -box_normal , iorBtoA );

    if length( refractedRD ) > 0.0
    {
      let refractedRD = normalize( refractedRD );
      let F = freshel( refractedRD, box_normal, F0, CRITICAL_ANGLE_ATOB );
      let background_color = draw_background( new_ro, refractedRD, light_source );
      final_color += ( 1.0 - F ) * background_color * exp( -distance_traveled * 1.0 * vec3f( 1.0 - COLOR_ABSORPTION ) ) * attenuation;
    }

    let edge_t = smooth_box_edge( new_ro );
    let edge_color =  mix( final_color, BOX_EDGE_COLOR, edge_t );
    final_color = mix( final_color, edge_color, smoothstep(  0.0,  1.0, exp( -distance_traveled / 3.0 ) ) );

    attenuation *= F;
    prev_ro = new_ro;
    prev_rd = reflectedRD;
  }

  return final_color;
}

fn generate_stars
(
  uv_in : vec2f,
  grid_size : f32,
  star_size : f32,
  ray_width : f32,
  twinkle : bool
) -> vec3f
{
  //var final_color = vec3f( 0.0 );

  let uv = uv_in * grid_size;
  let cell_id = floor( uv );
  let cell_coords = fract( uv ) - 0.5;
  var star_coords = hash2dx2d( cell_id ) - 0.5;
  star_coords -= vec2f( star_size * 2.0 );

  let delta_coords = abs( star_coords - cell_coords );
  // Distance to the star from the cell coordinates
  let dist = length( delta_coords );
  var glow = vec3f( exp( -5.0 * length( dist ) / ( star_size * 2.0 ) ) );

  let brightness = remap( 0.0, 1.0, 0.5, 1.0, hash2dx1d( uv + vec2f( 404.045, -123.423) ) );

  if twinkle
  {
    let twinkle_change = remap( -1.0, 1.0, 0.5, 1.0, sin( u.time * 3.0 + uv.x * uv.y ) );
    let rays = smoothstep( ray_width, 0, delta_coords.x ) * smoothstep( star_size * twinkle_change, 0, dist ) +
    smoothstep( ray_width, 0, delta_coords.y ) * smoothstep( star_size * twinkle_change, 0, dist );
    
    glow = glow * rays;
  }

  return glow * brightness;
}

fn draw_stars
(
  rd_in : vec3f,
) -> vec3f
{
  var final_color = vec3f( 0.0 );

  let theta = atan2( rd_in.x, rd_in.z );
  let phi = asin( rd_in.y );

  let normalization = vec2f( 0.1591, 0.3183 );
  var uv = vec2f( theta, phi ) * normalization + vec2f( 0.5 );
  var grid_size = 10.0;
  var star_size = 0.08;
  let ray_width = 0.005;
  let star_color = vec3f( 1.0 );

  let star_size_change = 0.8;
  let grid_size_change = 1.5;

  // Big start are animated
  for( var i = 0; i < 3; i++ )
  {
    final_color += generate_stars( uv, grid_size, star_size, ray_width, true );
    star_size *= star_size_change;
    grid_size *= grid_size_change;
  }

  // Small stars are not animated
  for( var i = 3; i < 5; i++ )
  {
    final_color += generate_stars( uv, grid_size, star_size, ray_width, false );
    star_size *= star_size_change;
    grid_size *= grid_size_change;
  }

  return final_color;
}

fn draw_sea
(
  p_in : vec3f,
  rd_in : vec3f
) -> vec3f
{
  let step_size = 1.0;

  var current_p = p_in;
  var prev_p = vec3f( 0.0 );
  var current_sea_height =  1.0 - sea_noise( p_in );
  var prev_sea_height = -1.0;
  var count = 0;
  while abs( current_p.y + 1.01 ) < current_sea_height
  {
    if count > 16 { break; }
    prev_sea_height = current_sea_height;
    prev_p = current_p;
    current_p = current_p + rd_in * step_size;
    current_sea_height = 1.0 - sea_noise( current_p );
    count += 1;
  } 

  let after_d = current_sea_height - abs( current_p.y+ 1.01 );
  let before_d = prev_sea_height - abs( prev_p.y+ 1.01 );
  var p = mix( current_p, prev_p, after_d / ( after_d - before_d ) );

  let normal = sea_normal( p ); 
  let F = freshel( -rd_in, normal, vec3f( 0.04 ), 0.0 );

  let LdotN = saturate( dot( normal, MOON_LIGHT_DIR ) );
  let H = normalize( MOON_LIGHT_DIR - rd_in );
  let phong_value = pow( dot( H, normal ), 32.0 );

  let reflectedRD = normalize( reflect( rd_in, normal ) );
  let stars_color = F * draw_stars( reflectedRD );

  let diffuse_color = ( 1.0 - F ) * LdotN * vec3f( 0.8,0.9,0.6 ) * 0.6 + phong_value;
  var color = stars_color + diffuse_color;

  //color = normal;

  return color;
}

fn sea_octave( uv_in : vec2f, choppy : f32 ) -> f32
{
  // Offset the uv value in y = x direction by the noise value
  let uv = uv_in + perlin_noise2dx1d( uv_in );
  var s_wave = 1.0 - abs( sin( uv ) );
  let c_wave = abs( cos( uv ) );
  // Smooth out the waves
  s_wave = mix( s_wave, c_wave, s_wave );
  // Shuffle the resulting values, I guess
  // Minus from 1.0 - for the wave to cave in
  return pow( 1.0 - pow( s_wave.x * s_wave.y, 0.65 ), choppy );
}

// Fbm based sea noise
fn sea_noise( p : vec3f ) -> f32
{
  var freq = 0.16;
  var amp = 0.6; // Height
  var choppy = 4.0;
  let octave_m = mat2x2( 1.6, 1.2, -1.2, 1.6 );
  var uv = p.xz; 
  uv.x *= 0.75;
  
  var d = 0.0;
  var h = 0.0;    

  for( var i = 0; i < 5; i++ ) 
  { 
    // Mix two octaves for better detail
    d = sea_octave( ( uv + u.time ) * freq, choppy ) + sea_octave( ( uv - u.time ) * freq, choppy );
    // Add the height of the current octave to the sum
    h += d * amp;        
    // deform uv domain( rotate and stretch)
    uv *= octave_m; 
    freq *= 1.9; 
    amp *= 0.22;
    choppy = mix( choppy, 1.0, 0.2 );
  }

  return h;
}

fn sea_normal( p : vec3f ) -> vec3f
{
  let e = 0.01;
  let offset = vec2f( 1.0, 0.0 ) * e;
  let dfdx = ( sea_noise( p + offset.xyy ) - sea_noise( p - offset.xyy ) );
  let dfdz = ( sea_noise( p + offset.yyx ) - sea_noise( p - offset.yyx ) );
  let normal = normalize( vec3f( -dfdx, 2.0 * e, -dfdz ) );
  return normal;
}

fn draw_patch
(
  ro_in : vec3f, 
  rd_in : vec3f,
  color_out : ptr< function, vec3f >
)
{
  // Plane size
  let ps = vec4f( -1.0, -1.0, 1.0, 1.0 ) * 1.0;
  // Plane height
  let ph = vec4f( -1.0, 1.0, 1.0, -1.0 ) * 0.5;

  var ro = ro_in;
  var rd = rd_in;

  for( var i = 0; i < 3; i++)
  {
    // Rotate the camera to get a view from a different angle
    var ro = rotz( 3.1415926 * f32( i ) / 3.0 ) * ro_in;
    var rd = rotz( 3.1415926 * f32( i ) / 3.0 ) * rd_in;

    var color = vec3f( 0.0 );
    var c1 =  vec3f( 1.0, 0.0, 0.0 );
    var c2 =  vec3f( 1.0, 0.0, 0.0 );

    let t = iBilinearPatch( ro, rd, ps, ph );

    // Precalculate colors
    // fwidth is not allowed to be called from a non-uniform flow, so we precalculate some values
    // even if they will not be used
    {
      var hit = ro + t * rd;
      c1 = pallete( length( hit ) );
      // Move a tiny bit forwrad to prevent itersection with at the current hit
      hit = hit + 0.00001 * rd;

      let t2 = iBilinearPatch( hit, rd, ps, ph );
      hit = hit + t2 * rd;
      c2 =  pallete( length( hit ) );
    }

    if t > 0.0
    {
      var hit = ro + t * rd;
      if all( abs( hit ) <= vec3f( 1.0001 ) )
      {
        *color_out += c1;
      }
      else
      {
        hit = hit + 0.00001 * rd;
        let t2 = iBilinearPatch( hit, rd, ps, ph );
        hit = hit + t2 * rd;

        if all( abs( hit ) <= vec3f( 1.0001 ) )
        {
          *color_out += c2;
        }
      }
    }
  }
}

fn raytrace_box
(
  ro : vec3f, 
  rd : vec3f, 
  normal : ptr< function, vec3f >, // Normal at the hit point
  entering : bool
)  -> f32
{
  // Having an equation ro + t * rd, we calculate an intersection `t` with 3 planes : xy, xz, and yz.
  // we calculate `t`, such that our ray hits the planes xy, xz, yz.
  // The result for each plane is stored in z, y, x coordinates of the `t` variable respectively.
  let dr = 1.0 / rd;
  let t = ro * dr;
  // Now we need to offset the `t` to hit planes that build the box.
  // If we take a point in the corner of the box and calculate the distance needed to travel from that corner
  // to all three planes, we can then take that distance and subtruct/add to our `t`, to get the proper hit value.
  let dt = BOX_DIMENSIONS * abs( dr );
  
  // Planes facing us are closer, so we need to subtruct
  let pin = - dt - t;
  // Planes behind the front planes are farther, so we need to add
  let pout =  dt - t;

  // From the distances to all the front and back faces, we find faces of the box that are actually hit by the ray
  let tin = max( pin.x, max( pin.y, pin.z ) );
  let tout = min( pout.x, min( pout.y, pout.z) );

  // Ray is outside of the box
  if tin > tout
  { 
    return -1.0;
  }

  // Calculate the normal
  if entering
  {
    *normal = -sign( rd ) * step( pin.zxy, pin.xyz ) * step( pin.yzx, pin.xyz );
  } 
  else 
  {
    *normal = sign (rd ) * step( pout.xyz, pout.zxy ) * step( pout.xyz, pout.yzx );
  }

  return select( tout, tin, entering );
}


//>> Bilinear Patch
// It's a plane that is by parametric equation using 4 points in space.
// f( u, v ) = ( 1 - u) * ( 1 - v ) * p00 + u * ( 1 - v ) * p10 + ( 1 - u ) * v * p01 + u * v * p11;
// Taken from here: https://pbr-book.org/4ed/Shapes/Bilinear_Patches
//
// The following two functions are taken from this shader: https://www.shadertoy.com/view/ltKBzG
// It take as input the following
// ro - ray origin
// rd - ray direction
// ps - plane size | ps.xy - define the minimun and px.zw - the maximux in size of the plane. Basically like a bounding box.
// ph - plane height | Defines the height( Y ) of the plane at each of the 4 points. X and Z coordinatez are defined by the ps
//
// Having defined a bilinear patch and a line `ro + t * rd`, it finds `t` with which the line intersects the plane and returns the `t`
fn iBilinearPatch( ro : vec3f, rd : vec3f, ps : vec4f, ph : vec4f ) -> f32
{
  let va : vec3f = vec3f( 0.0, 0.0, ph.x + ph.w - ph.y - ph.z );
  let vb : vec3f = vec3f( 0.0, ps.w - ps.y, ph.z - ph.x );
  let vc : vec3f = vec3f( ps.z - ps.x, 0.0, ph.y - ph.x );
  let vd : vec3f = vec3f( ps.xy, ph.x );

  let tmp = 1.0 / ( vb.y * vc.x );
  let a = 0.0;
  let b = 0.0;
  let c = 0.0;
  let d = va.z * tmp;
  let e = 0.0;
  let f = 0.0;
  let g = (vc.z * vb.y - vd.y * va.z) * tmp;
  let h = (vb.z * vc.x - va.z * vd.x) * tmp;
  let i = -1.0;
  let j = (vd.x * vd.y * va.z + vd.z * vb.y * vc.x) * tmp
          - (vd.y * vb.z * vc.x + vd.x * vc.z * vb.y) * tmp;

  let p = dot( vec3f( a, b, c ), rd.xzy * rd.xzy )
          + dot( vec3f( d, e, f ), rd.xzy * rd.zyx );
  let q = dot( vec3f( 2.0, 2.0, 2.0 ) * ro.xzy * rd.xyz, vec3f (a, b, c ) )
          + dot( ro.xzz * rd.zxy, vec3f( d, d, e ) )
          + dot( ro.yyx * rd.zxy, vec3f( e, f, f ) )
          + dot( vec3f( g, h, i ), rd.xzy );
  let r = dot( vec3f( a, b, c ), ro.xzy * ro.xzy )
          + dot( vec3f( d, e, f ), ro.xzy * ro.zyx )
          + dot( vec3f( g, h, i ), ro.xzy ) + j;
  if abs( p ) < 0.000001 
  {
    return -r / q;
  } 
  else 
  {
    let sq = q * q - 4.0 * p * r;
    if sq < 0.0 
    {
      return 0.0;
    } 
    else 
    {
      let s = sqrt( sq );
      let t0 = ( -q + s ) / ( 2.0 * p );
      let t1 = ( -q - s ) / ( 2.0 * p );

      // Short way to type:
      // return min(t0 < 0.0 ? t1 : t0, t1 < 0.0 ? t0 : t1);
      // in wgsl
      return min( mix( t1, t0, step( 0.0, t0 ) ), mix( t0, t1, step( 0.0, t1 ) ) );
    }
  }
}

/// If pos - position on the plane defined by ps and ph, then it return the normal at that point.
fn nBilinearPatch( ps : vec4f,  ph : vec4f, pos : vec3f ) -> vec3f
{
  let va = vec3f( 0.0, 0.0, ph.x + ph.w - ph.y - ph.z );
  let vb = vec3f( 0.0, ps.w - ps.y, ph.z - ph.x );
  let vc = vec3f( ps.z - ps.x, 0.0, ph.y - ph.x );
  let vd = vec3f( ps.xy, ph.x );

  let tmp = 1.0 / ( vb.y * vc.x );
  let a = 0.0;
  let b = 0.0;
  let c = 0.0;
  let d = va.z * tmp;
  let e = 0.0;
  let f = 0.0;
  let g = ( vc.z * vb.y - vd.y * va.z ) * tmp;
  let h = ( vb.z * vc.x - va.z * vd.x ) * tmp;
  let i = -1.0;
  let j = ( vd.x * vd.y * va.z + vd.z * vb.y * vc.x ) * tmp
          - ( vd.y * vb.z * vc.x + vd.x * vc.z * vb.y ) * tmp;

  let grad = vec3f( 2.0 ) * pos.xzy * vec3f( a, b, c )
    + pos.zxz * vec3f( d, d, e )
    + pos.yyx * vec3f( f, e, f )
    + vec3f( g, h, i );
  return -normalize( grad );
}
//<< Bilinear Patch

//
// Different utilities
//

// Schlick ver.
fn freshel( view_dir : vec3f, halfway : vec3f, f0 : vec3f, critical_angle_cosine : f32 ) -> vec3f
{
  let VdotH = dot( view_dir, halfway );
  // Case of full reflection
  if( VdotH < critical_angle_cosine ) 
  {
    return vec3( 1.0 );
  }

  return f0 + ( 1.0 - f0 ) * pow( ( 1.0 - VdotH ), 5.0 );
}


// The following function is taken from https://www.shadertoy.com/view/WlffDn
// Function fcos() is a band-limited cos(x).
//
// Box-filtering of cos(x):
//
// (1/w)∫cos(t)dt with t ∈ (x-½w, x+½w)
// = [sin(x+½w) - sin(x-½w)]/w
// = cos(x)·sin(½w)/(½w)
//
// Can approximate smoothstep(2π,0,w) ≈ sin(w/2)/(w/2),
// which you can also see as attenuating cos(x) when it 
// oscilates more than once per pixel. More info:
//
// https://iquilezles.org/articles/bandlimiting
fn fcos( x : vec3f ) -> vec3f
{
  let w = fwidth( x );
  return cos( x ) * ( 1.0 - smoothstep( vec3f( 0.0 ), vec3f( 3.14 * 2.0 ), w ) ); // filtered-approx
}

// This function calculates smooth cos several times, each time decreasing frequency( and changing the offset a little ),
// creating a more detailed ( more strips ) pallete.
fn pallete( t : f32 ) -> vec3f
{
    var col = vec3( 0.3,0.4,0.5 );
    col += 0.12 * fcos( 6.28318 * t *   1.0 + vec3( 0.0, 0.8, 1.1 ) );
    col += 0.11 * fcos( 6.28318 * t *   3.1 + vec3( 0.3, 0.4, 0.1 ) );
    col += 0.10 * fcos( 6.28318 * t *   5.1 + vec3( 0.1, 0.7, 1.1 ) );
    col += 0.10 * fcos( 6.28318 * t *  17.1 + vec3( 0.2, 0.6, 0.7 ) );
    col += 0.10 * fcos( 6.28318 * t *  31.1 + vec3( 0.1, 0.6, 0.7 ) );
    col += 0.10 * fcos( 6.28318 * t *  65.1 + vec3( 0.0, 0.5, 0.8 ) );
    col += 0.10 * fcos( 6.28318 * t * 115.1 + vec3( 0.1, 0.4, 0.7 ) );
    col += 0.10 * fcos( 6.28318 * t * 265.1 + vec3( 1.1, 1.4, 2.7 ) );
    
    return col;
}

fn rotz( angle : f32 ) -> mat3x3< f32 >
{
  let s = sin( angle );
  let c = cos( angle );
  return mat3x3< f32 >
  (
    c, s, 0.0,
    -s, c, 0.0,
    0.0, 0.0, 1.0
  );
}

fn rotx( angle : f32 ) -> mat3x3< f32 >
{
  let s = sin( angle );
  let c = cos( angle );
  return mat3x3< f32 >
  (
    1.0, 0.0, 0.0,
    0.0, c, s,
    0.0, -s, c
  );
}

fn roty( angle : f32 ) -> mat3x3< f32 >
{
  let s = sin( angle );
  let c = cos( angle );
  return mat3x3< f32 >
  (
    c, 0.0, -s,
    0.0, 1.0, 0.0,
    s, 0.0, c
  );
}

fn hash2dx1d( p : vec2f ) -> f32
{
	let h = dot( p, vec2f( 127.1,311.7 ) );	
  return fract( sin( h ) * 43758.5453123 );
}

fn hash2dx2d( uv : vec2f ) -> vec2f 
{
  let transform1 = mat2x2( -199.258, 457.1819, -1111.1895, 2244.185 );
  let transform2 = mat2x2( 111.415, -184.0, -2051.0, 505.0 );
  return fract( transform1 * sin( transform2 * uv ) );
}

fn hash3dx1d( uv : vec3f ) -> f32 
{
  let v = dot( uv, vec3f( 4099.4363 , -1193.2417, 7643.1409  ) );
  return fract( sin( v ) * 43758.5453123 );
}

fn hash3dx3d( uv : vec3f ) -> vec3f 
{
  let v = vec3f
  (
    dot( uv, vec3f( 701.124, -439.552, 617.622 ) ),
    dot( uv, vec3f( -821.634, 97.23, 397.754 ) ),
    dot( uv, vec3f( 67.421, 853.863, -997.933 ) ),
  );
  return fract( sin( v ) * 43758.5453123 );
}

fn perlin_noise2dx1d( p : vec2f ) -> f32
{
  let i = floor( p );
  let f = fract( p );	
	let u = smoothstep( vec2f( 0.0 ), vec2f( 1.0 ), f );

  let noise = mix( mix( hash2dx1d( i + vec2( 0.0,0.0 ) ), 
                        hash2dx1d( i + vec2( 1.0,0.0 ) ), u.x ),
                   mix( hash2dx1d( i + vec2( 0.0,1.0 ) ), 
                        hash2dx1d( i + vec2( 1.0,1.0 ) ), u.x ), u.y );

  return noise * 2.0 - 1.0;
}

fn remap( t_min_in : f32, t_max_in : f32, t_min_out : f32, t_max_out : f32, v : f32 ) -> f32
{
  let k = ( v - t_min_in ) / ( t_max_in - t_min_in );
  return mix( t_min_out, t_max_out, k );
}

fn aces_tonemap( color : vec3f ) -> vec3f
{  
  let m1 = mat3x3
  (
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
  );
  let m2 = mat3x3
  (
    1.60475, -0.10208, -0.00327,
    -0.53108,  1.10813, -0.07276,
    -0.07367, -0.00605,  1.07602
  );
  let v = m1 * color;  
  let a = v * ( v + 0.0245786 ) - 0.000090537;
  let b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
  return pow( clamp( m2 * ( a / b ), vec3f( 0.0 ), vec3f( 1.0 ) ), vec3f( 1.0 / 2.2 ) );  
}

// Some very barebones but fast atmosphere approximation
fn extra_cheap_atmosphere( raydir : vec3f, sundir : vec3f ) -> vec3f
{
  //sundir.y = max(sundir.y, -0.07);
  let special_trick = 1.0 / (raydir.y * 1.0 + 0.1);
  let special_trick2 = 1.0 / (sundir.y * 11.0 + 1.0);
  let raysundt = pow(abs(dot(sundir, raydir)), 2.0);
  let sundt = pow(max(0.0, dot(sundir, raydir)), 8.0);
  let mymie = sundt * special_trick * 0.2;
  let suncolor = mix(vec3(1.0), max(vec3f(0.0), vec3(1.0) - vec3f(5.5, 13.0, 22.4) / 22.4), special_trick2);
  let bluesky= vec3f(5.5, 13.0, 22.4) / 22.4 * suncolor;
  var bluesky2 = max(vec3(0.0), bluesky - vec3f(5.5, 13.0, 22.4) * 0.002 * (special_trick + -6.0 * sundir.y * sundir.y));
  bluesky2 *= special_trick * (0.24 + raysundt * 0.24);
  return bluesky2 * (1.0 + 1.0 * pow(1.0 - raydir.y, 3.0));
} 

// Get atmosphere color for given direction
fn getAtmosphereColor( dir : vec3f ) -> vec3f
{
  return extra_cheap_atmosphere( dir, MOON_LIGHT_DIR ) * 0.5;
}

// Get sun color for given direction
fn getSunColor( dir : vec3f ) -> vec3f 
{ 
  return vec3f( pow( max( 0.0, dot( dir, MOON_LIGHT_DIR ) ), 720.0 ) * 210.0 );
}