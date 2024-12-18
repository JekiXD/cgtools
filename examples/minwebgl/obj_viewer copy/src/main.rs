//! Just draw a large point in the middle of the screen.

use std::
{
  sync::{ Arc, Mutex }
};

use mingl::CameraOrbitControls;
use minwebgl::{ self as gl, JsCast };
use gl::
{
  GL,
};



mod camera_controls;

async fn run() -> Result< (), gl::WebglError >
{
  gl::browser::setup( Default::default() );
  let canvas = gl::canvas::make()?;
  let gl = gl::context::from_canvas( &canvas )?;

  let width = canvas.width() as f32;
  let height = canvas.height() as f32;

  // Camera setup
  let eye = gl::math::F32x3::from( [ 0.0, 5.0, 0.2 ] );
  let up = gl::math::F32x3::from( [ 0.0, 1.0, 0.0 ] );
  let center = gl::math::F32x3::from( [ 0.0, 0.0, 0.0 ] );

  let aspect_ratio = width / height;
  let fov = 70.0f32.to_radians();
  let perspective_matrix = gl::math::mat3x3h::perspective_rh_gl
  (
    fov,  
    aspect_ratio, 
    0.1, 
    10000.0
  );

  let camera = CameraOrbitControls
  {
    eye : eye,
    up : up,
    center : center,
    window_size : [ width, height ].into(),
    fov,
    ..Default::default()
  };
  let camera = Arc::new( Mutex::new( camera ) );

  camera_controls::setup_controls( &canvas, &camera );

  let vertex_shader_src = include_str!( "../shaders/shader.vert" );
  let fragment_shader_src = include_str!( "../shaders/shader.frag" );
  let program = gl::ProgramFromSources::new( vertex_shader_src, fragment_shader_src ).compile_and_link( &gl )?;
  gl.use_program( Some( &program ) );

  let eye_loc = gl.get_uniform_location( &program, "eye" );
  let up_loc = gl.get_uniform_location( &program, "up" );
  let dir_loc = gl.get_uniform_location( &program, "viewDir" );
  let res_loc = gl.get_uniform_location( &program, "resolution" );

  // Define the update and draw logic
  let update_and_draw =
  {
    move | t : f64 |
    {
      let _time = t as f32 / 1000.0;

      let center = camera.lock().unwrap().center();
      let eye = camera.lock().unwrap().eye();
      let up = camera.lock().unwrap().up();

      let dir = ( center - eye ).normalize();

      gl::uniform::upload( &gl, eye_loc.clone(), &eye.to_array()[ .. ] ).unwrap();
      gl::uniform::upload( &gl, up_loc.clone(), &up.to_array()[ .. ] ).unwrap();
      gl::uniform::upload( &gl, dir_loc.clone(), &dir.to_array()[ .. ] ).unwrap();
      gl::uniform::upload( &gl, res_loc.clone(), &[ canvas.width() as f32, canvas.height() as f32 ][ .. ] ).unwrap();

      gl.draw_arrays( gl::TRIANGLE_STRIP, 0, 4 );
      true
    }
  };

  // Run the render loop
  gl::exec_loop::run( update_and_draw );

  Ok( () )
}

fn main()
{
  gl::spawn_local( async move { run().await.unwrap() } );
}
