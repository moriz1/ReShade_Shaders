/**
    Depth-based defog and DoF shader for Guild Wars 2
    The DoF effect is a modified version of the LightDoF shader that comes with ReShade 3

    By moriz0 
 */

uniform float DefogStart <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 1.00;
> = 0.31;

uniform float DefogEnd <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 1.00;
> = 1.00;

uniform float DefogFalloffPoint <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 1.00;
> = 0.70;

uniform float DefogExposure <
    ui_type = "drag";
    ui_min = -1.00; ui_max = 1.00;
> = 0.00;

uniform float DefogSaturation <
    ui_type = "drag";
    ui_min = -1.00; ui_max = 1.00;
> = -0.28;

uniform float DefogContrast <
    ui_type = "drag";
    ui_min = -1.00; ui_max = 1.00;
> = 0.00;

uniform float DefogAmount <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 1.00;
> = 0.09;

uniform bool FogAutoColor <
    ui_label = "Use Auto Defog Color";
    ui_tooltip = "Autodetects fog color, and uses the inverse to defog. This disables the FogColor variable";
> = false;

uniform float3 FogColor <
	ui_type = "color";
	ui_label = "Defog Color";
> = float3(0.5, 0.5, 0.5);

uniform float fLightDoF_Width <
	ui_label = "Bokeh Width [Light DoF]";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 25.0;
> = 5.0;

uniform float fLightDoF_Amount <
	ui_label = "DoF Amount [Light DoF]";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
> = 10.0;

uniform bool bLightDoF_UseCA <
	ui_label = "Use Chromatic Aberration [Light DoF]";
	ui_tooltip = "Use color channel shifting.";
> = true;

uniform float f2LightDoF_CA <
	ui_label = "Chromatic Aberration [Light DoF]";
	ui_tooltip = "Shifts color channels.";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.66;

uniform float fLightDoF_FocusOffset <
	ui_label = "Focus Offset [Light DoF]";
    ui_tooltip = "Adjust until UI elements aren't blurred";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.64;

uniform bool DebugDepthBuffer <
    ui_tooltip = "Switch to depth buffer view";
> = false;

uniform bool DebugEnable <
    ui_tooltip = "Turn on debug view";
> = false;

texture DefogColorBuffer : COLOR;

sampler SamplerDefogColor { Texture = DefogColorBuffer; };

#include "ReShade.fxh"

float AdjustDepth(float depth) {
    float adjustedDepth = 0.0;

    if (depth > DefogStart) {
        if (depth < DefogEnd) {
            adjustedDepth = depth - DefogStart;
        }
        else if (depth >= DefogEnd && depth < 1.0) {
            adjustedDepth = DefogEnd - DefogStart;
        }
        else {
            adjustedDepth = 1.0;
        }
    }
    return adjustedDepth;
}

//interpret the focus textures and separate far/near focuses
float getFocus(float2 coord) {
	float depth = ReShade::GetLinearizedDepth(coord);
    float adjustedDepth = AdjustDepth(depth);

	adjustedDepth -= fLightDoF_FocusOffset;
	adjustedDepth = saturate(adjustedDepth * fLightDoF_Amount);
	
	return adjustedDepth;
}

//helper function for poisson-disk blur
float2 rot2D(float2 pos, float angle) {
	float2 source = float2(sin(angle), cos(angle));
	return float2(dot(pos, float2(source.y, -source.x)), dot(pos, source));
}

//poisson-disk blur
float3 poisson(sampler sp, float2 uv, float distanceMulti) {
	float2 poisson[12];
	poisson[0]  = float2(-.326,-.406);
	poisson[1]  = float2(-.840,-.074);
	poisson[2]  = float2(-.696, .457);
	poisson[3]  = float2(-.203, .621);
	poisson[4]  = float2( .962,-.195);
	poisson[5]  = float2( .473,-.480);
	poisson[6]  = float2( .519, .767);
	poisson[7]  = float2( .185,-.893);
	poisson[8]  = float2( .507, .064);
	poisson[9]  = float2( .896, .412);
	poisson[10] = float2(-.322,-.933);
	poisson[11] = float2(-.792,-.598);
	
	float3 col = 0;
	float random = frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
	float4 basis = float4(rot2D(float2(1, 0), random), rot2D(float2(0, 1), random));
	[unroll]
	for (int i = 0; i < 12; ++i) {
		float2 offset = poisson[i] * distanceMulti;
		offset = float2(dot(offset, basis.xz), dot(offset, basis.yw));
		
        if (bLightDoF_UseCA) {
			float2 rCoord = uv + offset * ReShade::PixelSize * fLightDoF_Width * (1.0 + f2LightDoF_CA);
			float2 gCoord = uv + offset * ReShade::PixelSize * fLightDoF_Width * (1.0 + f2LightDoF_CA * 0.5);
			float2 bCoord = uv + offset * ReShade::PixelSize * fLightDoF_Width;
			
			rCoord = lerp(uv, rCoord, getFocus(rCoord));
			gCoord = lerp(uv, gCoord, getFocus(gCoord));
			bCoord = lerp(uv, bCoord, getFocus(bCoord));
			
			col += 	float3(
						tex2Dlod(sp, float4(rCoord, 0, 0)).r,
						tex2Dlod(sp, float4(gCoord, 0, 0)).g,
						tex2Dlod(sp, float4(bCoord, 0, 0)).b
					);
		}
        else {
		    float2 coord = uv + offset * ReShade::PixelSize * fLightDoF_Width;
		    coord = lerp(uv, coord, getFocus(coord));
		    col += tex2Dlod(sp, float4(coord, 0, 0)).rgb;
        }
		
	}
	return col * 0.083;
}

float4 DefogPass(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target {
    float4 color = tex2D(ReShade::BackBuffer, texcoord.xy);
    float3 diffColor = 0.0;
    float3 newColor = color.rgb;

    float depth = ReShade::GetLinearizedDepth(texcoord);
    float adjustedDepth = AdjustDepth(depth);
    float defogAmount = DefogAmount;

    if (depth > DefogStart && adjustedDepth < 1.0) {
        if (DebugEnable) {
            color = adjustedDepth;
        }
        else {
            newColor = newColor * (1.0 - DefogContrast * adjustedDepth) + (0.5 * DefogContrast * adjustedDepth);

            if (depth > DefogFalloffPoint) {
                defogAmount = DefogAmount - (DefogAmount * (depth - DefogFalloffPoint) / (1.0 - DefogFalloffPoint)) / 1.5;
            }

            if (FogAutoColor) {
                newColor = saturate(newColor - (adjustedDepth * defogAmount) * (1.0 - tex2D(SamplerDefogColor, texcoord).rgb) * 2.55);
            }
            else {
                newColor = saturate(newColor - (adjustedDepth * defogAmount) * FogColor * 2.55);
            }

            newColor *= pow(2.0f, adjustedDepth*DefogExposure);

            diffColor = newColor - dot(newColor, (1.0 / 3.0));
            newColor = (newColor + diffColor * adjustedDepth * DefogSaturation) / (1 + (diffColor * adjustedDepth * DefogSaturation));

            color.rgb = newColor;
        }
    }

    if (DebugDepthBuffer) {
        color = depth;
    }

    return float4(color.xyz, 0);
}

//far blur shader
float3 Far(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target {
    float depth = ReShade::GetLinearizedDepth(uv);
    float4 color = tex2D(ReShade::BackBuffer, uv.xy);

    if (depth > DefogStart && depth < 1.0) {
	    return poisson(ReShade::BackBuffer, uv, depth);
    }
    else {
        return color.xyz;
    }
}

technique Defog {
    pass defog {
        VertexShader = PostProcessVS;
        PixelShader = DefogPass;
    }
}

//technique for far blur
technique LightDoF_Far {
	pass Far {
		VertexShader=PostProcessVS;
		PixelShader=Far;
	}
}