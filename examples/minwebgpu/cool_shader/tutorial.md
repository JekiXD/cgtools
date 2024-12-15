
### Basic setup
We are going to create our custom shaders based on this shader [Cube lines](https://www.shadertoy.com/view/NslGRN). I'm going to do this using WebGPU as my backend, and WGSL as a shader language. Skipping the setup explanation, in my shader I'm going to have the following uniform variables:

```rust
struct Uniforms
{
  eye : vec3f,          // Position of the camera
  view_dir: vec3f,      // Camera's view direction
  up : vec3f,           // Cumera's orientation
  resolution : vec2f,   // Resolution of the screen
  time : f32            // Total time passed
}
```
Camera control logic happens outside of the shader, so I can just use camera's information as it is in the shader.
 
Now with the shader. First we need to generate our rays. For this we need to have a ray origin( `ro` ), which is going to be our camera's position, and a ray direction( `rd` ), which we are going to calculate ourselves. The idea is to generate them in simple to calculate coordinates, and then to rotate them to match the view direction and orientation of the camera.  

We are going to place our origin at ( 0.0, 0.0, 0.0 ) and shoot ray in +Z direction. The X and Y coordinates will be decided from the fragment posiiton on the screen:

```rust
var rd = vec3f( ( in.pos.xy * 2.0 - u.resolution ) / u.resolution.x, 0.7 );
rd.y *= -1.0;
```

We shift a fragment position to be centered at the  origin( [ 0.0, 0.0 ]), and then we normalize them by the width of the screen. This way we are going to have uniform speed across X and Y axis, when we move our camera. Z value define FOV ofthe camera - the bigger it is, the more zoomed in the view will be. We flip the Y axis, because fragment coordinates start at left-upper corner, and we need it to start at the left-bottom corner.

Now we need to define the camera's coordinate system, whose unit vectors will define the rotation that we need to perform on our rays:

```rust
// Orthonormal vectors of the view transformation
let vz = normalize( u.view_dir );
var vy = normalize( u.up );
let vx = normalize( cross( vz, vy ) );
vy = normalize( cross( vx, vz ) );
```

In camera's coordinate system, Z axis will point in the `view` direction, Y axis in the `Up` direction, and X axis will be perpendicular to the Y and Z. We normalize all vectors to be sure they are `1` in length.   

Now we apply camera's rotation to our rays:

```rust
rd = normalize( vx * rd.x + vy * rd.y + vz * rd.z );
```

An intuitive explanation, as to how this rotation work is we assume are rays are defined in camera's local coordinate system. What we need is to find the coordinates of our rays in the world space. Orthonormal vectors, that define camera's coordinate system, are all defined in world space coordinates. So to find, for example, the X coordinate of our ray in the world space, we just need to find the contribution of each if its components( defined in local spcae ) to the X coordinate in the world space. We multiply each component by the X value of its corresponding orthonormal vector and sum them together getting the X coordinate in the world space for our vector. Other axises are done in the same way.

Here are a few resources to help with understanding:
- [ Fundamentals of Computer Graphics ](https://www.amazon.com/Fundamentals-Computer-Graphics-Steve-Marschner/dp/1482229390)
- [ Confused with Coordinate Transformations ](https://computergraphics.stackexchange.com/questions/12594/confused-with-coordinate-transformations) 
- [  Computer Graphics
Chapter – 7 (part - B) ](https://imruljubair.github.io/teaching/material/CSE4203/Chapter%20-%207%20(part%20-%20B).pdf)





