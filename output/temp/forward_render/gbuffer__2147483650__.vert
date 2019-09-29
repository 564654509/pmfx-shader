#version 450 core
#define GLSL
#define BINDING_POINTS
//forward_render gbuffer__2147483650__ vs 2147483650
#ifdef GLES
// precision qualifiers
precision highp float;
precision highp sampler2DArray;
#endif
// texture
#ifdef BINDING_POINTS
#define _tex_binding(sampler_index) layout(binding = sampler_index)
#else
#define _tex_binding(sampler_index)
#endif
#define texture_2d( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2D sampler_name
#define texture_3d( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler3D sampler_name
#define texture_cube( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform samplerCube sampler_name
#define texture_2d_array( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2DArray sampler_name
#ifdef GLES
#define sample_texture_2dms( sampler_name, x, y, fragment ) texture( sampler_name, vec2(0.0, 0.0) )
#define texture_2dms( type, samples, sampler_name, sampler_index ) uniform sampler2D sampler_name
#else
#define sample_texture_2dms( sampler_name, x, y, fragment ) texelFetch( sampler_name, ivec2( x, y ), fragment )
#define texture_2dms( type, samples, sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2DMS sampler_name
#endif
// sampler
#define sample_texture( sampler_name, V ) texture( sampler_name, V )
#define sample_texture_level( sampler_name, V, l ) textureLod( sampler_name, V, l )
#define sample_texture_grad( sampler_name, V, vddx, vddy ) textureGrad( sampler_name, V, vddx, vddy )
#define sample_texture_array( sampler_name, V, a ) texture( sampler_name, vec3(V, a) )
#define sample_texture_array_level( sampler_name, V, a, l ) textureLod( sampler_name, vec3(V, a), l )
// matrix
#define to_3x3( M4 ) float3x3(M4)
#define from_columns_3x3(A, B, C) (transpose(float3x3(A, B, C)))
#define from_rows_3x3(A, B, C) (float3x3(A, B, C))
#define unpack_vb_instance_mat( mat, r0, r1, r2, r3 ) mat[0] = r0; mat[1] = r1; mat[2] = r2; mat[3] = r3;
#define to_data_matrix(mat) mat
// clip
#define remap_z_clip_space( d ) d // gl clip space is -1 to 1, and this is normalised device coordinate
#define remap_depth( d ) (d = d * 0.5 + 0.5)
#define remap_ndc_ray( r ) float2(r.x, r.y)
#define depth_ps_output gl_FragDepth
// def
#define float4x4 mat4
#define float3x3 mat3
#define float2x2 mat2
#define float4 vec4
#define float3 vec3
#define float2 vec2
#define modf mod
#define frac fract
#define lerp mix
#define mul( A, B ) ((A) * (B))
#define mul_tbn( A, B ) ((B) * (A))
#define saturate( A ) (clamp( A, 0.0, 1.0 ))
#define atan2( A, B ) (atan(A, B))
#define ddx dFdx
#define ddy dFdy
#define _pmfx_unroll
#define chebyshev_normalize( V ) (V.xyz / max( max(abs(V.x), abs(V.y)), abs(V.z) ))
#define max3(v) max(max(v.x, v.y),v.z)
#define max4(v) max(max(max(v.x, v.y),v.z), v.w)
#define PI 3.14159265358979323846264
layout(location = 0) in float4 position_vs_input;
layout(location = 1) in float4 normal_vs_input;
layout(location = 2) in float4 texcoord_vs_input;
layout(location = 3) in float4 tangent_vs_input;
layout(location = 4) in float4 bitangent_vs_input;
layout(location = 5) in float4 blend_indices_vs_input;
layout(location = 6) in float4 blend_weights_vs_input;
layout(location = 1) out float4 world_pos_vs_output;
layout(location = 2) out float3 normal_vs_output;
layout(location = 3) out float3 tangent_vs_output;
layout(location = 4) out float3 bitangent_vs_output;
layout(location = 5) out float4 texcoord_vs_output;
layout(location = 6) out float4 colour_vs_output;
struct vs_input_multi
{
    float4 position;
    float4 normal;
    float4 texcoord;
    float4 tangent;
    float4 bitangent;
    float4 blend_indices;
    float4 blend_weights;
};
struct vs_output
{
    float4 position;
    float4 world_pos;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    float4 texcoord;
    float4 colour;
};
struct light_data
{
    float4 pos_radius;
    float4 dir_cutoff;
    float4 colour;
    float4 data;
};
struct distance_field_shadow
{
    float4x4 world_matrix;
    float4x4 world_matrix_inv;
};
struct area_light_data
{
    float4 corners[4];
    float4 colour;
};
layout (binding= 2,std140) uniform skinning_info
{
    float4x4 bones[85];
};
layout (binding= 0,std140) uniform per_pass_view
{
    float4x4 vp_matrix;
    float4x4 view_matrix;
    float4x4 vp_matrix_inverse;
    float4x4 view_matrix_inverse;
    float4 camera_view_pos;
    float4 camera_view_dir;
    float4 viewport_correction;
};
layout (binding= 1,std140) uniform per_draw_call
{
    float4x4 world_matrix;
    float4 user_data;
    float4 user_data2;
    float4x4 world_matrix_inv_transpose;
};
layout (binding= 7,std140) uniform material_data
{
    float4 m_albedo;
    float2 m_uv_scale;
    float m_roughness;
    float m_reflectivity;
};
float4 skin_pos(float4 pos, float4 weights, float4 indices)
{
    int bone_indices[4];
    bone_indices[0] = int(indices.x);
    bone_indices[1] = int(indices.y);
    bone_indices[2] = int(indices.z);
    bone_indices[3] = int(indices.w);
    float4 sp = float4( 0.0, 0.0, 0.0, 0.0 );
    float final_weight = 1.0;
    for(int i = 3; i >= 0; --i)
    {
        sp += mul( pos, bones[bone_indices[i]] ) * weights[i];
        final_weight -= weights[i];
    }
    sp += mul( pos, bones[bone_indices[0]] ) * final_weight;
    sp.w = 1.0;
    return sp;
}
void skin_tbn(inout float3 t, inout float3 b, inout float3 n, float4 weights, float4 indices)
{
    int bone_indices[4];
    bone_indices[0] = int(indices.x);
    bone_indices[1] = int(indices.y);
    bone_indices[2] = int(indices.z);
    bone_indices[3] = int(indices.w);
    float3 rt = float3( 0.0, 0.0, 0.0);
    float3 rb = float3( 0.0, 0.0, 0.0);
    float3 rn = float3( 0.0, 0.0, 0.0);
    float final_weight = 1.0;
    for( int i = 0; i < 3; ++i)
    {
        float3x3 rot_mat = to_3x3(bones[bone_indices[i]]);
        rt += mul(t, rot_mat) * weights[i];
        rb += mul(b, rot_mat) * weights[i];
        rn += mul(n, rot_mat) * weights[i];
        final_weight -= weights[i];
    }
    float3x3 rot_mat = to_3x3(bones[bone_indices[3]]);
    rt += mul(t, rot_mat) * final_weight;
    rb += mul(b, rot_mat) * final_weight;
    rn += mul(n, rot_mat) * final_weight;
    t = rt;
    b = rb;
    n = rn;
}
void main()
{
    //assign vs_input_multi struct from glsl inputs
    vs_input_multi _input;
    _input.position = position_vs_input;
    _input.normal = normal_vs_input;
    _input.texcoord = texcoord_vs_input;
    _input.tangent = tangent_vs_input;
    _input.bitangent = bitangent_vs_input;
    _input.blend_indices = blend_indices_vs_input;
    _input.blend_weights = blend_weights_vs_input;
    vs_output _output;
    float4x4 wvp = mul( world_matrix, vp_matrix );
    float4x4 wm = world_matrix;
    _output.texcoord = float4(_input.texcoord.x, 1.0 - _input.texcoord.y,
    _input.texcoord.z, 1.0 - _input.texcoord.w );
    _output.colour = m_albedo;
    float4 sp = skin_pos(_input.position, _input.blend_weights, _input.blend_indices);
    _output.tangent = _input.tangent.xyz;
    _output.bitangent = _input.bitangent.xyz;
    _output.normal = _input.normal.xyz;
    skin_tbn(_output.tangent, _output.bitangent, _output.normal, _input.blend_weights, _input.blend_indices);
    _output.position = mul( sp, vp_matrix );
    _output.world_pos = sp;
    float3 scale = float3(length(world_matrix[0].xyz),
    length(world_matrix[1].xyz),
    length(world_matrix[2].xyz));
    float xs = length(_input.tangent.xyz * scale);
    float ys = length(_input.bitangent.xyz * scale);
    _output.texcoord *= float4(m_uv_scale.x * xs, m_uv_scale.y * ys, m_uv_scale.x, m_uv_scale.y);
    //assign glsl global outputs from structs
    gl_Position = _output.position;
    world_pos_vs_output = _output.world_pos;
    normal_vs_output = _output.normal;
    tangent_vs_output = _output.tangent;
    bitangent_vs_output = _output.bitangent;
    texcoord_vs_output = _output.texcoord;
    colour_vs_output = _output.colour;
}
