#include <metal_stdlib>
using namespace metal;
// texture
#define texture2d_rw( name, index ) texture2d<float, access::read_write> name [[texture(index)]]
#define texture2d_r( name, index ) texture2d<float, access::read> name [[texture(index)]]
#define texture2d_w( name, index ) texture2d<float, access::write> name [[texture(index)]]
#define read_texture( name, gid ) name.read(gid)
#define write_texture( name, val, gid ) name.write(val, gid)
#define texture_2d( name, sampler_index ) texture2d<float> name [[texture(sampler_index)]], sampler sampler_##name [[sampler(sampler_index)]]
#define texture_3d( name, sampler_index ) texture3d<float> name [[texture(sampler_index)]], sampler sampler_##name [[sampler(sampler_index)]]
#define texture_2dms( type, samples, name, sampler_index ) texture2d_ms<float> name [[texture(sampler_index)]], sampler sampler_##name [[sampler(sampler_index)]]
#define texture_cube( name, sampler_index ) texturecube<float> name [[texture(sampler_index)]], sampler sampler_##name [[sampler(sampler_index)]]
#define texture_2d_array( name, sampler_index ) texture2d_array<float> name [[texture(sampler_index)]], sampler sampler_##name [[sampler(sampler_index)]]
#define texture_2d_arg(name) thread texture2d<float>& name, thread sampler& sampler_##name
#define texture_3d_arg(name) thread texture3d<float>& name, thread sampler& sampler_##name
#define texture_2dms_arg(name) thread texture2d_ms<float>& name, thread sampler& sampler_##name
#define texture_cube_arg(name) thread texturecube<float>& name, thread sampler& sampler_##name
#define texture_2d_array_arg(name) thread texture2d_array<float>& name, thread sampler& sampler_##name
// structured buffers
#define structured_buffer_rw( type, name, index ) device type* name [[buffer(index)]]
#define structured_buffer_rw_arg( type, name, index ) device type* name [[buffer(index)]]
#define structured_buffer( type, name, index ) constant type& name [[buffer(index)]]
#define structured_buffer_arg( type, name, index ) constant type& name [[buffer(index)]]
// sampler
#define sample_texture( name, tc ) name.sample(sampler_##name, tc)
#define sample_texture_2dms( name, x, y, fragment ) name.read(uint2(x, y), fragment)
#define sample_texture_level( name, tc, l ) name.sample(sampler_##name, tc, level(l))
#define sample_texture_grad( name, tc, vddx, vddy ) name.sample(sampler_##name, tc, gradient3d(vddx, vddy))
#define sample_texture_array( name, tc, a ) name.sample(sampler_##name, tc, uint(a))
#define sample_texture_array_level( name, tc, a, l ) name.sample(sampler_##name, tc, uint(a), level(l))
// matrix
#define to_3x3( M4 ) float3x3(M4[0].xyz, M4[1].xyz, M4[2].xyz)
#define from_columns_3x3(A, B, C) (transpose(float3x3(A, B, C)))
#define from_rows_3x3(A, B, C) (float3x3(A, B, C))
#define mul( A, B ) ((A) * (B))
#define mul_tbn( A, B ) ((B) * (A))
#define unpack_vb_instance_mat( mat, r0, r1, r2, r3 ) mat[0] = r0; mat[1] = r1; mat[2] = r2; mat[3] = r3;
#define to_data_matrix(mat) mat
// clip
#define remap_z_clip_space( d ) (d = d * 0.5 + 0.5)
#define remap_ndc_ray( r ) float2(r.x, r.y)
#define remap_depth( d ) (d)
// defs
#define ddx dfdx
#define ddy dfdy
#define discard discard_fragment
#define lerp mix
#define frac fract
#define mod(x, y) (x - y * floor(x/y))
#define _pmfx_unroll
//GENERIC MACROS
#define chebyshev_normalize( V ) (V.xyz / max( max(abs(V.x), abs(V.y)), abs(V.z) ))
#define max3(v) max(max(v.x, v.y),v.z)
#define max4(v) max(max(max(v.x, v.y),v.z), v.w)
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
struct c_skinning_info
{
    float4x4 bones[85];
};
struct packed_vs_input_skinned
{
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
    float4 texcoord [[attribute(2)]];
    float4 tangent [[attribute(3)]];
    float4 bitangent [[attribute(4)]];
    float4 blend_indices [[attribute(5)]];
    float4 blend_weights [[attribute(6)]];
};
struct vs_input_skinned
{
    float4 position;
    float4 normal;
    float4 texcoord;
    float4 tangent;
    float4 bitangent;
    float4 blend_indices;
    float4 blend_weights;
};
struct vs_output_pre_skin
{
    float4 vb_position;
    float4 normal;
    float4 tangent;
    float4 bitangent;
    float4 texcoord;
};
float4 skin_pos(constant float4x4* bones,
float4 pos,
float4 weights,
float4 indices)
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
vertex void vs_main(
uint vid [[vertex_id]]
, uint iid [[instance_id]]
, packed_vs_input_skinned in_vertex [[stage_in]]
,  device vs_output_pre_skin* stream_out_vertices[[buffer(7)]]
, constant c_skinning_info &skinning_info [[buffer(10)]])
{
    vs_input_skinned input;
    input.position = float4(in_vertex.position);
    input.normal = float4(in_vertex.normal);
    input.texcoord = float4(in_vertex.texcoord);
    input.tangent = float4(in_vertex.tangent);
    input.bitangent = float4(in_vertex.bitangent);
    input.blend_indices = float4(in_vertex.blend_indices);
    input.blend_weights = float4(in_vertex.blend_weights);
    constant float4x4* bones = &skinning_info.bones[0];
    vs_output_pre_skin output;
    float4 sp = skin_pos(bones, input.position, input.blend_weights, input.blend_indices);
    output.vb_position = sp;
    output.normal = input.normal;
    output.tangent = input.tangent;
    output.bitangent = input.tangent;
    output.texcoord = input.texcoord;
    stream_out_vertices[vid] = output;
}
