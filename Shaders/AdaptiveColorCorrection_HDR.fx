/**
 * Adaptive Color Correction w/ HDR
 * Not HDR in the slightest. Just an experiment
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

uniform bool DebugLumaOutput <
    ui_label = "Show Luma Output";
	ui_tooltip = "Black/White mode!";
> = false;

uniform float LumaHigh <
	ui_label = "Luma Max Threshold";
	ui_tooltip = "Luma above this level uses full Daytime LUT\nSet higher than Min Threshold";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = 0.90;

uniform float2 MidRange <
	ui_label = "Luma Mid Points";
	ui_tooltip = "Luma within this level will use standard colors\nSet between LumaLow and LumaHigh";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = float2(0.4, 0.7);

uniform float LumaLow <
	ui_label = "Luma Min Threshold";
	ui_tooltip = "Luma below this level uses full NightTime LUT\nSet lower than Max Threshold";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
> = 0.20;

#include "ReShade.fxh"

texture texLUTDay < source = fLUT_TextureDay; > { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
sampler	SamplerLUTDay	{ Texture = texLUTDay; };

texture texLUTNight < source = fLUT_TextureNight; > { Width = fLUT_TileSizeXY*fLUT_TileAmount; Height = fLUT_TileSizeXY; Format = RGBA8; };
sampler	SamplerLUTNight	{ Texture = texLUTNight; };


float4 ApplyLUTHDR(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target {
	float4 color = tex2D(ReShade::BackBuffer, texcoord.xy).rgba;
	color.a = pow((color.r*2 + color.b + color.g*3) / 6, 1/2.2);

	if (DebugLumaOutput) {
		float temp = color.a;
		return float4(temp, temp, temp, temp);
	}

	if (color.a >= MidRange.x && color.a <= MidRange.y) {
		return float4(color.rgb, 1.0);
	}

	float2 texelsize = 1.0 / fLUT_TileSizeXY;
	texelsize.x /= fLUT_TileAmount;

	float3 lutcoord = float3((color.xy*fLUT_TileSizeXY-color.xy+0.5)*texelsize.xy,color.z*fLUT_TileSizeXY-color.z);
	float lerpfact = frac(lutcoord.z);

	lutcoord.x += (lutcoord.z-lerpfact)*texelsize.y;
	
	float3 lutcolor = lerp(tex2D(SamplerLUTDay, lutcoord.xy).xyz, tex2D(SamplerLUTDay, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);
	float3 lutcolor2 =lerp(tex2D(SamplerLUTNight, lutcoord.xy).xyz, tex2D(SamplerLUTNight, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);	

	float3 color1 = 0.0;
	float3 color2 = 0.0;

	color1.xyz = lutcolor.xyz;
	color2.xyz = lutcolor2.xyz;

	float highlights = (color.a - MidRange.y)/(LumaHigh - MidRange.y);
	float shadows = (color.a - LumaLow)/(MidRange.x - LumaLow);

	if (highlights > 0) {
		color.xyz = lerp(color.xyz, color1.xyz, highlights);
	}
	else if (shadows > 0) {
		color.xyz = lerp(color2.xyz, color.xyz, shadows);
	}

	color.w = 1.0;

	return color;
}

technique AdaptiveColorCorrection_HDR {
	pass Apply_LUT {
		VertexShader = PostProcessVS;
		PixelShader = ApplyLUTHDR;
	}
}
