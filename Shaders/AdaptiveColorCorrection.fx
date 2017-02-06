/**
 * Adaptive Color Correction
 * Runs two LUTs simultaneously, smoothly lerping between them based on luma.
 * By moriz1
 * Original LUT shader by Marty McFly
 */

#ifndef fLUT_TextureDay
	#define fLUT_TextureDay "lutDAY.png"
#endif
#ifndef fLUT_TextureNight
	#define fLUT_TextureNight "lutNIGHT.png"
#endif
#ifndef fLUT_TileSizeXY
	#define fLUT_TileSizeXY 32
#endif
#ifndef fLUT_TileAmount
	#define fLUT_TileAmount 32
#endif

uniform bool DebugLuma <
    ui_label = "Show Luma Debug Bars";
	ui_tooltip = "Draws debug bars on top left of screen";
> = false;

uniform bool DebugLumaOutput <
    ui_label = "Show Luma Output";
	ui_tooltip = "Black/White mode!";
> = false;

uniform float LumaChangeSpeed <
	ui_label = "Adaptation Speed";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = 0.05;

uniform float LumaHigh <
	ui_label = "Luma Max Threshold";
	ui_tooltip = "Luma above this level uses full Daytime LUT\nSet higher than Min Threshold";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = 0.4;

uniform float LumaLow <
	ui_label = "Luma Min Threshold";
	ui_tooltip = "Luma below this level uses full NightTime LUT\nSet lower than Max Threshold";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = 0.25;

#include "ReShade.fxh"

texture LumaInputTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R8; MipLevels = 6; };
sampler LumaInputSampler { Texture = LumaInputTex; MipLODBias = 6.0f; };

texture LumaTex { Width = 1; Height = 1; Format = R8; };
sampler LumaSampler { Texture = LumaTex; };

texture LumaTexLF { Width = 1; Height = 1; Format = R8; };
sampler LumaSamplerLF { Texture = LumaTexLF; };

texture texLUTDay < source = fLUT_TextureDay; > { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
sampler	SamplerLUTDay	{ Texture = texLUTDay; };

texture texLUTNight < source = fLUT_TextureNight; > { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
sampler	SamplerLUTNight	{ Texture = texLUTNight; };

float SampleLuma(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float luma = 0.0;

	int width = BUFFER_WIDTH / 64;
	int height = BUFFER_HEIGHT / 64;

	for (int i = width/3; i < 2*width/3; i++) {
		for (int j = height/3; j < 2*height/3; j++) {
			luma += tex2Dlod(LumaInputSampler, float4(i, j, 0, 6)).x;
		}
	}

	luma /= (width * 1/3) * (height * 1/3);

	float lastFrameLuma = tex2D(LumaSamplerLF, float2(0.5, 0.5)).x;

	return lerp(lastFrameLuma, luma, LumaChangeSpeed);
}

float LumaInput(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float3 color = tex2D(ReShade::BackBuffer, texcoord).xyz;
	
	//gonna cheat and store luma info in the alpha channel
	return pow((color.r*2 + color.b + color.g*3) / 6, 1/2.2);
}

float4 ApplyLUT(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float4 color = tex2D(ReShade::BackBuffer, texcoord.xy);
	float2 texelsize = 1.0 / fLUT_TileSizeXY;
	texelsize.x /= fLUT_TileAmount;

	if (DebugLumaOutput) {
		float temp = tex2D(LumaInputSampler, texcoord.xy).x;
		return float4(temp, temp, temp, temp);
	}

	float3 lutcoord = float3((color.xy*fLUT_TileSizeXY-color.xy+0.5)*texelsize.xy,color.z*fLUT_TileSizeXY-color.z);
	float lerpfact = frac(lutcoord.z);

	lutcoord.x += (lutcoord.z-lerpfact)*texelsize.y;
	
	float3 lutcolor = lerp(tex2D(SamplerLUTDay, lutcoord.xy).xyz, tex2D(SamplerLUTDay, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
	float3 lutcolor2 =lerp(tex2D(SamplerLUTNight, lutcoord.xy).xyz, tex2D(SamplerLUTNight, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);	

	float lumaVal = tex2D(LumaSampler, float2(0.5, 0.5)).x;

	if (DebugLuma) {
		if (texcoord.y <= 0.01 && texcoord.x <= 0.01) {
			return lumaVal;
		}
		if (texcoord.y <= 0.01 && texcoord.x > 0.01 && texcoord.x <= 0.02) {
			if (lumaVal > LumaHigh) {
				return float4(1.0, 1.0, 1.0, 1.0);
			}
			else {
				return float4(0.0, 0.0, 0.0, 1.0);
			}
		}
		if (texcoord.y <= 0.01 && texcoord.x > 0.02 && texcoord.x <= 0.03) {
			if (lumaVal <= LumaHigh && lumaVal >= LumaLow) {
				return float4(1.0, 1.0, 1.0, 1.0);
			}
			else {
				return float4(0.0, 0.0, 0.0, 1.0);
			}
		}
		if (texcoord.y <= 0.01 && texcoord.x > 0.03 && texcoord.x <= 0.04) {
			if (lumaVal < LumaLow) {
				return float4(1.0, 1.0, 1.0, 1.0);
			}
			else {
				return float4(0.0, 0.0, 0.0, 1.0);
			}
		}
	}

	float3 color1 = 0.0;
	float3 color2 = 0.0;

	color1.xyz = lutcolor.xyz;
	color2.xyz = lutcolor2.xyz;

	if (lumaVal > LumaHigh) {
		color.xyz = color1.xyz;
	}
	else if (lumaVal < LumaLow) {
		color.xyz = color2.xyz;
	}
	else {
		color.xyz = (color1.xyz * (lumaVal - LumaLow)/(LumaHigh - LumaLow)) + (color2.xyz * (1 - ((lumaVal - LumaLow)/(LumaHigh - LumaLow))));
	}

	color.w = 1.0;

	return color;
}

float SampleLumaLF(float4 position : SV_Position, float2 texcoord: TexCoord) : SV_Target {
	return tex2D(LumaSampler, float2(0.5, 0.5)).x;
}

technique AdaptiveColorCorrection {
	pass Input {
		VertexShader = PostProcessVS;
		PixelShader = LumaInput;
		RenderTarget = LumaInputTex
	;
	}
	pass StoreLuma {
		VertexShader = PostProcessVS;
		PixelShader = SampleLuma;
		RenderTarget = LumaTex;
	}
	pass Apply_LUT {
		VertexShader = PostProcessVS;
		PixelShader = ApplyLUT;
	}
	pass StoreLumaLF {
		VertexShader = PostProcessVS;
		PixelShader = SampleLumaLF;
		RenderTarget = LumaTexLF;
	}
}
