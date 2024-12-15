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

// Shaders used:
// https://www.shadertoy.com/view/MdKXzc


const PI : f32 = 3.14159265;
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
// Drawing Nebula is quite expensive, so be careful with the amount of reflections
const NUM_REFLECTIONS : i32 = 2;
const BOX_DIMENSIONS : vec3f = vec3f( 0.5, 1.0, 0.5 );
// Distance to the edges
const BOX_DTE : vec3f = vec3f( length( BOX_DIMENSIONS.xz ), length( BOX_DIMENSIONS.xy ), length( BOX_DIMENSIONS.yz ) );
const CRITICAL_ANGLE_ATOB : f32 = sqrt( max( 0.0, 1.0 - iorBtoA * iorBtoA ) );
const CRITICAL_ANGLE_BTOA : f32 = sqrt( max( 0.0, 1.0 - iorAtoB * iorAtoB ) );
const LIGHT_POWER : f32 = 8.0;
const BOX_EDGE_COLOR : vec3f = vec3f( 0.0 );
const MOON_LIGHT_DIR : vec3f = normalize( vec3f( -1.0, 1.0, -1.0 ) );
const PLANE_P : vec3f = vec3f( 0.0, -1.01, 0.0 );
const M : vec2f = vec2f( 1.0, 0.0 );
const INSIDES_NOISE : f32 = 0.3;
const WATER_INTENSITY : f32 = 0.5;
const INNER_BOX_SCALE : f32 = 6.0;
const TRANSPARENT_BOX : bool = false;

@fragment
fn fs_main( in : VSOut ) -> @location( 0 ) vec4f
{
  // Ray origin
  let ro = u.eye;
  var light_source = normalize( vec3f( -1.0, 1.0, -1.0 ) ) * vec3f( 4.75, 4.0, 4.75 );

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

  if all( abs( ro ) < BOX_DIMENSIONS )
  {
    final_color = draw_box_background( ro * INNER_BOX_SCALE, rd );
  }
  else
  {
     final_color = draw_background( ro, rd, light_source );

    var box_normal : vec3f;
    let box_t = raytrace_box( ro, rd, &box_normal, BOX_DIMENSIONS, true );


    if box_t > 0.0
    {
      final_color = vec3f( 0.0 );
      var ro = ro + box_t * rd;

      let w = box_normal;
      let u = normalize( M.xyy * w.z - M.yyx * w.x - M.yyx * w.y );
      let v = normalize( M.yxy * w.z + M.yxy * w.x - M.xyy * w.y );
      let TBN = mat3x3( u, w, v );

      var uv = ro.xy * w.z + ro.xz * w.y + ro.yz * w.x;
      uv *= INSIDES_NOISE;

      let n = normalize( TBN * water_normal( uv ) );

      let F = freshel( -rd, n, F0, CRITICAL_ANGLE_ATOB );
      var refractedRD = refract( rd, n, iorAtoB );
      let reflectedRD = normalize( reflect( rd, n ) );

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
  }

  //return vec4f( aces_tonemap( final_color ), 1.0 );
  //return vec4f( pow( final_color, vec3f( 1.0 / 2.2 ) ), 1.0 );
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

fn draw_background
(
  ro_in : vec3f,
  rd_in : vec3f,
  light_source : vec3f
) -> vec3f
{
  var final_color = vec3f( 0.0 );
  let plane_size = 6.0;
  let blur_radius = 5.0;
  let plane_normal = vec3f( 0.0, 1.0, 0.0 ); // Normal of the plane
  let p0 = PLANE_P; // Any point on the plane

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

      var diff_color = vec3f( 1.0 );
      var plane_color = ( LdotN * diff_color + phong_value );
      plane_color *= attenuation; 

      let shad = boxSoftShadow( plane_hit, normalize( light_source - plane_hit ), BOX_DIMENSIONS, 2.0 );
      plane_color *= smoothstep( -0.2, 1.0, shad );

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
  }

  return pow( final_color, vec3f( 1.0 / 2.2 ) );
}

fn draw_box_background
(
  ro_in : vec3f,
  rd_in : vec3f
) -> vec3f
{
  var final_color = vec3f( 0.0 );

  final_color += draw_stars( rd_in );
  final_color += draw_nebula( ro_in, rd_in );

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
    let inside_color = draw_box_background( prev_ro * INNER_BOX_SCALE, prev_rd );
    final_color += inside_color * attenuation;

    var box_normal : vec3f;
    let box_t = raytrace_box( prev_ro, prev_rd, &box_normal, BOX_DIMENSIONS, false );

    var new_ro = prev_ro + box_t * prev_rd;
    distance_traveled += length( prev_ro - new_ro );

    let w = box_normal;
    let u = M.xyy * w.z - M.yyx * w.x - M.yyx * w.y;
    let v = M.yxy * w.z + M.yxy * w.x - M.xyy * w.y;
    let TBN = mat3x3( u, w, v );

    var uv = new_ro.xy * w.z + new_ro.xz * w.y + new_ro.yz * w.x;
    uv *= INSIDES_NOISE;

    let n = TBN * water_normal( uv );

    let F = freshel( prev_rd, n, F0, CRITICAL_ANGLE_BTOA );
    let reflectedRD = normalize( reflect( prev_rd, -n ) );
    let refractedRD = refract( prev_rd, -n , iorBtoA );

    // Makes the box transparent
    if TRANSPARENT_BOX
    {
      if length( refractedRD ) > 0.0
      {
        let refractedRD = normalize( refractedRD );
        let F = freshel( refractedRD, n, F0, CRITICAL_ANGLE_ATOB );
        let background_color = draw_background( new_ro, refractedRD, light_source );
        final_color += ( 1.0 - F ) * background_color * exp( -distance_traveled * 1.0 * vec3f( 1.0 - COLOR_ABSORPTION ) ) * attenuation;
      }

      let edge_t = smooth_box_edge( new_ro );
      let edge_color =  mix( final_color, BOX_EDGE_COLOR, edge_t );
      final_color = mix( final_color, edge_color, smoothstep(  0.0,  1.0, exp( -distance_traveled / 3.0 ) ) );
    }

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
  var star_size = 0.07;
  let ray_width = 0.005;
  let star_color = vec3f( 1.0 );

  let star_size_change = 0.9;
  let grid_size_change = 1.6;

  // Big start are animated
  for( var i = 0; i < 3; i++ )
  {
    final_color += generate_stars( uv, grid_size, star_size, ray_width, true );
    star_size *= star_size_change;
    grid_size *= grid_size_change;
  }

  star_size *= 0.8;

  // Small stars are not animated
  for( var i = 3; i < 6; i++ )
  {
    final_color += generate_stars( uv, grid_size, star_size, ray_width, false );
    star_size *= star_size_change;
    grid_size *= grid_size_change;
  }

  return final_color;
}

// https://www.shadertoy.com/view/MdKXzc
fn draw_nebula( ro : vec3f, rd : vec3f ) -> vec3f
{
  // Redius of the sphere that envelops the nebula
  let radius = 4.0;// + INNER_BOX_SCALE * 0.5 * smoothstep( -1.0, 1.0, sin( u.time * 0.7 ) );
  // Max density
  let h = 0.1;
  let optimal_radius = 4.0;
  let k = optimal_radius / radius;

  var p : vec3f;
  var final_color = vec4f( 0.0 );
  var local_density = 0.0;
  var total_density = 0.0;
  var weight = 0.0;

  let vt = raytrace_sphere( ro, rd, vec3f( 0.0 ), radius );
  // Itersection point when entering the sphere
  let tin = vt.x;
  // Intersection point when exiting the sphere
  let tout = vt.y;
  var t = max( tin, 0.0 );

  // If sphere was hit
  if any( vt != vec2f( -1.0 ) )
  { 
    for( var i = 0; i < 64; i++ )
    {
      if total_density > 0.9 || t > tout { break; }

      // Current posiiton inside the sphere
      p = ro + t * rd;
      p *= k;
      // By feeding the 3d position we turn 3d domain into a 3d texture of densities
      // So we get the density at the current position
      let d = abs( nebula_noise( p * 3.0 ) * 0.5 ) + 0.07;

      // Distance to the light soure
      var ls_dst = max( length( p ), 0.001 ); 

      // The color of light 
      // https://www.shadertoy.com/view/cdK3Wy
      let _T = ls_dst * 2.3 + 2.6;
      var light_color = 0.4 + 0.5 * cos( _T + PI * 0.5 * vec3( -0.5, 0.15, 0.5 ) );
      final_color += vec4f( vec3f( 0.67, 0.75, 1.0 ) / ( ls_dst * ls_dst * 10.0 ) / 80.0, 0.0 ); // star itself
      final_color += vec4f( light_color / exp( ls_dst * ls_dst * ls_dst * 0.08 ) / 30.0, 0.0 ); // bloom

      if d < h
      {
        // Compute local density 
        local_density = h - d;
        // Compute weighting factor. The more density accumulated so far, the less weigth current local density has
        weight = ( 1.0 - total_density ) * local_density;
        // Accumulate density
        total_density += weight + 1.0 / 200.0;
        
        // Transparancy falls, as the density increases
        var col = vec4f( nebula_color( total_density, ls_dst ), total_density );

        // Emission. The densier the medium gets, the brighter it shines
        final_color += final_color.a * vec4( final_color.rgb, 0.0 ) * 0.2;	   
        // Uniform scale density
        col.a *= 0.2;
        // Color by alpha
        col *= vec4f( vec3f( col.a ), 1.0 );
        // Alpha blend in contribution
        final_color = final_color + col * ( 1.0 - final_color.a );
      }

      total_density += 1.0 / 70.0;
      // Optimize step size near the camera and near the light source. The densier field - the bigger step
      t += max( d * 0.1 * max( min( ls_dst, length( ro * k ) ), 1.0 ), 0.01 ) / k;
    }
  }

  // Simple scattering
	final_color *= 1.0 / exp( total_density * 0.2 ) * 0.8;

  return smoothstep( vec3f( 0.0 ), vec3f( 1.0 ), final_color.rgb );
}

fn nebula_color( density : f32, radius : f32 ) -> vec3f
{
	// Color based on density alone, gives impression of occlusion within the media
  var result = mix( vec3(1.0), vec3(0.5), density );
	
	// color added to the media
	let col_center = 7.0 * vec3( 0.8, 1.0, 1.0 );
	let col_edge = 1.5 * vec3( 0.48, 0.53, 0.5 );
	result *= mix( col_center, col_edge, min( ( radius + 0.05 ) / 0.9, 1.15 ) );
	return result;
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

fn raytrace_sphere( ro : vec3f, rd : vec3f, ce : vec3f, ra : f32 ) -> vec2f
{
  let oc = ro - ce;
  let b = dot( oc, rd );
  let c = dot( oc, oc ) - ra*ra;
  var h = b*b - c;
  if( h < 0.0 ) { return vec2( -1.0 ); } // no intersection
  h = sqrt( h );
  return vec2( -b-h, -b+h );
}

fn nebula_noise( p : vec3f ) -> f32
{
  var result = disk( p.xzy, vec3( 2.0, 1.8, 1.25 ) );
  result += spiral_noise( p.zxy * 0.5123 + 100.0 ) * 3.0;
  return result;
}

fn length2( p : vec2f ) -> f32
{
	return sqrt( p.x * p.x + p.y * p.y );
}

fn length8( p_in : vec2f ) -> f32
{
	var p = p_in * p_in; 
  p = p * p; 
  p = p * p;
	return pow( p.x + p.y, 1.0 / 8.0 );
}

fn disk( p : vec3f, t : vec3f ) -> f32
{
  let q = vec2( length2( p.xy ) - t.x, p.z * 0.5 );
  return max( length8( q ) - t.y, abs( p.z ) - t.z );
}

fn spiral_noise( p_in : vec3f ) -> f32
{
  var p = p_in;
  var n = 0.0;	// noise amount
  var iter = 2.0;
  let nudge = 0.9; // size of perpendicular vector
  let normalizer = 1.0 / sqrt( 1.0 + nudge * nudge ); // pythagorean theorem on that perpendicular to maintain scale
  for( var i = 0; i < 8; i++ )
  {
    // add sin and cos scaled inverse with the frequency
    n += -abs( sin( p.y * iter ) + cos( p.x * iter ) ) / iter;	// abs for a ridged look
    // rotate by adding perpendicular and scaling down
    p += vec3f( vec2f( p.y, -p.x ) * nudge, 0.0 );
    p *= vec3f( normalizer, normalizer, 1.0 );
    // rotate on other axis
    let tmp = vec2f( p.z, -p.x ) * nudge;
    p += vec3f( tmp.x, 0.0, tmp.y );
    p *= vec3f( normalizer, 1.0, normalizer );
    // increase the frequency
    iter *= 1.733733;
  }
  return n;
}

fn water_octave( uv_in : vec2f, choppy : f32 ) -> f32
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
fn water_noise( p : vec2f ) -> f32
{
  var freq = 0.16;
  var amp = 0.6;
  var choppy = 4.0;
  let octave_m = mat2x2( 1.6, 1.2, -1.2, 1.6 );
  var uv = p; 
  uv.x *= 0.75;
  
  var d = 0.0;
  var h = 0.0;    

  for( var i = 0; i < 5; i++ ) 
  { 
    // Mix two octaves for better detail
    d = water_octave( ( uv + u.time / 2.0 ) * freq, choppy ) + water_octave( ( uv - u.time / 2.0 ) * freq, choppy );
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

fn water_normal( p : vec2f ) -> vec3f
{
  let e = 0.01;
  let offset = vec2f( 1.0, 0.0 ) * e;
  let dfdx = ( water_noise( p + offset.xy ) - water_noise( p - offset.xy ) );
  let dfdz = ( water_noise( p + offset.yx ) - water_noise( p - offset.yx ) );
  let normal = normalize( vec3f( -dfdx, e / WATER_INTENSITY, -dfdz ) );
  return normal;
}

fn raytrace_box
(
  ro : vec3f, 
  rd : vec3f, 
  normal : ptr< function, vec3f >, // Normal at the hit point
  box_dimension : vec3f,
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
  let dt = box_dimension * abs( dr );
  
  // Planes facing us are closer, so we need to subtruct
  let pin = - dt - t;
  // Planes behind the front planes are farther, so we need to add
  let pout =  dt - t;

  // From the distances to all the front and back faces, we find faces of the box that are actually hit by the ray
  let tin = max( pin.x, max( pin.y, pin.z ) );
  let tout = min( pout.x, min( pout.y, pout.z ) );

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

// https://iquilezles.org/articles/boxfunctions/
// https://www.shadertoy.com/view/WslGz4
fn boxSoftShadow
( 
  ro : vec3f, 
  rd : vec3f,
  rad : vec3f,   // box semi-size
  sk : f32 
) -> f32
{
  let m = 1.0 / rd;
  let n = m * ro;
  let k = abs( m ) * rad;
  let t1 = -n - k;
  let t2 = -n + k;

  let tN = max( max( t1.x, t1.y ), t1.z );
  let tF = min( min( t2.x, t2.y ), t2.z );

  if( tN > tF || tF < 0.0 )
  {
    var sh = 1.0;
    sh = segShadow( ro.xyz, rd.xyz, rad.xyz, sh );
    sh = segShadow( ro.yzx, rd.yzx, rad.yzx, sh );
    sh = segShadow( ro.zxy, rd.zxy, rad.zxy, sh );
    return smoothstep( 0.0, 1.0, sk * sqrt( sh ) );
  }
  return 0.0;
}

fn dot2( v : vec3f ) -> f32 { return dot( v, v ); }

fn segShadow( ro : vec3f, rd : vec3f, pa : vec3f, sh_in : f32 ) -> f32
{
  var sh = sh_in;
  let k1 = 1.0 - rd.x * rd.x;
  let k4 = ( ro.x - pa.x ) * k1;
  let k6 = ( ro.x + pa.x ) * k1;
  let k5 = ro.yz * k1;
  let k7 = pa.yz * k1;
  let k2 = -dot( ro.yz, rd.yz );
  let k3 = pa.yz * rd.yz;
  
  for( var i = 0; i < 4; i++ )
  {
    let ss = vec2f( vec2i( i & 1, i >> 1 ) ) * 2.0 - 1.0;
    let thx = k2 + dot( ss, k3 );
    if( thx < 0.0 ) { continue; } // behind
    let thy = clamp( -rd.x * thx, k4, k6 );
    sh = min( sh, dot2( vec3f( thy, k5 - k7 * ss ) + rd * thx ) / ( thx * thx ) );
  }
  return sh;
}
