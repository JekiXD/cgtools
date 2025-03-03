use minwebgpu::{ self as gl };

use crate::{shader::ShaderComponents, uniform::UniformsState};

const HASH_GLUE : &'static str = include_str!( "../shaders/hash_glue.wgsl" );

pub struct Renderer
{
  pub uniforms_state : UniformsState,
  pub render_pipeline : gl::web_sys::GpuRenderPipeline,
  pub shader_components : ShaderComponents,
  pub vertex_shader_module : gl::web_sys::GpuShaderModule,
  pub final_fragment_shader_text : String,
  pub needs_shader_update : bool,
  pub presentation_format : gl::web_sys::GpuTextureFormat
}

impl Renderer
{
  pub fn new
  ( 
    device : &gl::web_sys::GpuDevice,
    document : &gl::web_sys::Document,
    presentation_format : gl::GpuTextureFormat,
    shader_components : ShaderComponents
  ) -> Result< Self, gl::WebGPUError >
  {
    let uniforms_state = UniformsState::new( device )?;
    let vertex_shader_module = gl::ShaderModule::new( include_str!( "../shaders/vertex_main.wgsl" ) ).create( &device );

    let mut final_fragment_shader_text = String::new();
    final_fragment_shader_text.push_str( &FRAGMENT_2D_MAIN );
    final_fragment_shader_text.push_str( &shader_components.hash );
    final_fragment_shader_text.push_str( &shader_components.noise );
    final_fragment_shader_text.push_str( &HASH_GLUE );

    let fragment_2d_main_shader = gl::ShaderModule::new( &final_fragment_shader_text ).create( &device );

    let render_pipeline = gl::render_pipeline::create
    (
      &device, 
      &gl::render_pipeline::desc( gl::VertexState::new( &vertex_shader_module ) )
      .layout
      ( 
        &gl::PipelineLayoutDescriptor::new()
        .bind_group( &uniforms_state.bind_group_layout )
        .create( device )
      )
      .fragment
      ( 
        gl::FragmentState::new( &fragment_2d_main_shader ) 
        .target
        ( 
          gl::ColorTargetState::new()
          .format( presentation_format ) 
        )
      )
      .into()
    )?;

    let needs_shader_update = false;

    let result = Renderer
    {
      uniforms_state,
      render_pipeline,
      shader_components,
      vertex_shader_module,
      final_fragment_shader_text,
      needs_shader_update,
      presentation_format
    };

    Ok( result )
  }

  pub fn update( &mut self, device : &gl::web_sys::GpuDevice, queue : &gl::web_sys::GpuQueue ) -> Result< (), gl::WebGPUError >
  {
    if self.needs_shader_update
    {
      self.update_fragment_shader( device );
      self.needs_shader_update = false;
    }

    self.uniforms_state.update( queue )?;

    Ok( () )
  }

  fn update_fragment_shader( &mut self, device : &gl::web_sys::GpuDevice )  -> Result< (), gl::WebGPUError >
  {
    self.final_fragment_shader_text.clear();
    self.final_fragment_shader_text.push_str( &FRAGMENT_2D_MAIN );
    self.final_fragment_shader_text.push_str( &self.shader_components.hash );
    self.final_fragment_shader_text.push_str( &self.shader_components.noise );
    self.final_fragment_shader_text.push_str( &HASH_GLUE );

    let fragment_shader_module = gl::ShaderModule::new( &self.final_fragment_shader_text ).create( &device );

    let render_pipeline = gl::render_pipeline::create
    (
      &device, 
      &gl::render_pipeline::desc( gl::VertexState::new( &self.vertex_shader_module ) )
      .layout
      ( 
        &gl::PipelineLayoutDescriptor::new()
        .bind_group( &self.uniforms_state.bind_group_layout )
        .create( device )
      )
      .fragment
      ( 
        gl::FragmentState::new( &fragment_shader_module ) 
        .target
        ( 
          gl::ColorTargetState::new()
          .format( self.presentation_format ) 
        )
      )
      .into()
    )?;

    self.render_pipeline = render_pipeline;

    Ok( () )
  }

  pub async fn set_hash( &mut self, hash : &str )
  {
    self.needs_shader_update = true;
    self.shader_components.load_hash( hash ).await;
  }

  pub async fn set_noise( &mut self, noise : &str )
  {
    self.needs_shader_update = true;
    self.shader_components.load_noise( noise ).await;
  }

  pub fn set_resolution( &mut self, resolution : gl::F32x2 )
  {
    self.uniforms_state.uniforms.resolution = resolution;
  }
}