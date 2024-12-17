//! Just draw a large point in the middle of the screen.

use std::sync::{Arc, Mutex};

use mingl::CameraOrbitControls;
use minwebgpu as gl;

mod camera_controls;

#[ repr( C ) ]
#[ derive( Clone, Copy, Default, gl::mem::Pod, gl::mem::Zeroable ) ]
struct Uniforms
{
  eye : [ f32; 3 ],
  _p1 : f32,
  view_dir : [ f32; 3 ],
  _p2 : f32,
  up : [ f32; 3 ],
  _p3 : f32,

  resolution : [ f32; 2 ],
  time : f32,
  _padding : [ f32; 1 ]
}

async fn run() -> Result< (), gl::WebGPUError >
{
  gl::browser::setup( Default::default() );
  let canvas = gl::canvas::retrieve_or_make()?;

  let context = gl::context::from_canvas( &canvas )?;
  let adapter = gl::context::request_adapter().await;
  let device = gl::context::request_device( &adapter ).await;
  let queue = device.queue();
  let presentation_format = gl::context::preferred_format();
  gl::context::configure( &device, &context, presentation_format )?;
  
  let shader = gl::ShaderModule::new( include_str!( "../shaders/shader_main.wgsl" ) ).create( &device );
  
  let render_pipeline = gl::render_pipeline::create
  (
    &device, 
    &gl::render_pipeline::desc( gl::VertexState::new( &shader ) )
    .fragment
    ( 
      gl::FragmentState::new( &shader ) 
      .target
      ( 
        gl::ColorTargetState::new()
        .format( presentation_format ) 
      )
    )
    .primitive( gl::PrimitiveState::new().triangle_strip() )
    .into()
  )?;

  let uniform_buffer = gl::BufferDescriptor::new( gl::BufferUsage::COPY_DST | gl::BufferUsage::UNIFORM )
  .size::< Uniforms >()
  .create( &device )?;

  let uniform_bind_group = gl::BindGroupDescriptor::new( &render_pipeline.get_bind_group_layout( 0 ) )
  .auto_bindings()
  .entry_from_resource( &gl::BufferBinding::new( &uniform_buffer ) )
  .create( &device );

  let eye = gl::math::F32x3::from( [ 0.0, 2.0, 2.0 ] );
  let up = gl::math::F32x3::from( [ 0.0, 1.0, 0.0 ] );
  let center = gl::math::F32x3::from( [ 0.0, 0.0, 0.0 ] );
  let fov = 70.0f32.to_radians();

  let camera = CameraOrbitControls
  {
    eye : eye,
    up : up,
    center : center,
    window_size : [ canvas.width() as f32, canvas.height() as f32 ].into(),
    fov,
    ..Default::default()
  };
  let camera = Arc::new( Mutex::new( camera ) );

  camera_controls::setup_controls( &canvas, &camera );


  // Define the update and draw logic
  let update_and_draw =
  {
    let mut prev_time = 0.0;
    move | t : f64 |
    {  
      let elapsed_time = ( ( t - prev_time ) / 1000.0 ) as f32;
      prev_time = t; 
      let t = ( t / 1000.0 ) as f32;

      let eye = camera.lock().unwrap().eye();
      let center = camera.lock().unwrap().center();
      let up = camera.lock().unwrap().up();

      let view_dir = center - eye;
      
      let uniforms = Uniforms
      {
        resolution : [ canvas.width() as f32, canvas.height() as f32 ],
        time : t,
        eye : eye.to_array(),
        up : up.to_array(),
        view_dir : view_dir.to_array(),
        ..Default::default()
      };

      gl::queue::write_buffer( &queue, &uniform_buffer, &[ uniforms ] ).unwrap();

      let canvas_texture = gl::context::current_texture( &context ).unwrap();
      let canvas_view = gl::texture::view( &canvas_texture ).unwrap();
    
      let command_encoder = device.create_command_encoder();
      let render_pass = command_encoder.begin_render_pass
      (
        &gl::render_pass::desc()
        .color_attachment( gl::ColorAttachment::new( &canvas_view ) )
        .into()
      ).unwrap();
    
      render_pass.set_pipeline( &render_pipeline );
      render_pass.set_bind_group( 0, Some( &uniform_bind_group ) );
      render_pass.draw( 4 );
      render_pass.end();

      gl::queue::submit( &queue, command_encoder.finish() );

      true
    }
  };

  // Run the render loop
  gl::exec_loop::run( update_and_draw );
  
  Ok(())
}

fn main()
{
  gl::spawn_local( async move { run().await.unwrap() } );
}
