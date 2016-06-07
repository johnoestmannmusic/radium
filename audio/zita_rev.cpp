//-----------------------------------------------------
//
// Code generated with Faust 0.9.73 (http://faust.grame.fr)
//-----------------------------------------------------
/* link with  */
#include <math.h>
#ifndef FAUSTPOWER
#define FAUSTPOWER
#include <cmath>
template <int N> inline float faustpower(float x)          { return powf(x,N); } 
template <int N> inline double faustpower(double x)        { return pow(x,N); }
template <int N> inline int faustpower(int x)              { return faustpower<N/2>(x) * faustpower<N-N/2>(x); } 
template <> 	 inline int faustpower<0>(int x)            { return 1; }
template <> 	 inline int faustpower<1>(int x)            { return x; }
template <> 	 inline int faustpower<2>(int x)            { return x*x; }
#endif
#include "Faust_plugins_template1.cpp"

/******************************************************************************
*******************************************************************************

							       VECTOR INTRINSICS

*******************************************************************************
*******************************************************************************/


/******************************************************************************
*******************************************************************************

			ABSTRACT USER INTERFACE

*******************************************************************************
*******************************************************************************/

//----------------------------------------------------------------------------
//  FAUST generated signal processor
//----------------------------------------------------------------------------

#ifndef FAUSTFLOAT
#define FAUSTFLOAT float
#endif  


#ifndef FAUSTCLASS 
#define FAUSTCLASS Zita_dsp
#endif

class Zita_dsp : public dsp {
  private:
	FAUSTFLOAT 	fslider0;
	int 	iConst0;
	float 	fConst1;
	float 	fRec11[2];
	FAUSTFLOAT 	fslider1;
	float 	fConst2;
	float 	fConst3;
	FAUSTFLOAT 	fslider2;
	FAUSTFLOAT 	fslider3;
	float 	fConst4;
	float 	fRec10[2];
	int 	IOTA;
	float 	fVec0[8192];
	float 	fConst5;
	int 	iConst6;
	float 	fVec1[8192];
	FAUSTFLOAT 	fslider4;
	float 	fConst7;
	float 	fVec2[2048];
	int 	iConst8;
	float 	fRec8[2];
	float 	fRec15[2];
	float 	fConst9;
	float 	fConst10;
	float 	fRec14[2];
	float 	fVec3[8192];
	float 	fConst11;
	int 	iConst12;
	float 	fVec4[1024];
	int 	iConst13;
	float 	fRec12[2];
	float 	fRec19[2];
	float 	fConst14;
	float 	fConst15;
	float 	fRec18[2];
	float 	fVec5[8192];
	float 	fConst16;
	int 	iConst17;
	float 	fVec6[2048];
	int 	iConst18;
	float 	fRec16[2];
	float 	fRec23[2];
	float 	fConst19;
	float 	fConst20;
	float 	fRec22[2];
	float 	fVec7[8192];
	float 	fConst21;
	int 	iConst22;
	float 	fVec8[1024];
	int 	iConst23;
	float 	fRec20[2];
	float 	fRec27[2];
	float 	fConst24;
	float 	fConst25;
	float 	fRec26[2];
	float 	fVec9[16384];
	float 	fConst26;
	int 	iConst27;
	float 	fVec10[8192];
	float 	fVec11[2048];
	int 	iConst28;
	float 	fRec24[2];
	float 	fRec31[2];
	float 	fConst29;
	float 	fConst30;
	float 	fRec30[2];
	float 	fVec12[8192];
	float 	fConst31;
	int 	iConst32;
	float 	fVec13[2048];
	int 	iConst33;
	float 	fRec28[2];
	float 	fRec35[2];
	float 	fConst34;
	float 	fConst35;
	float 	fRec34[2];
	float 	fVec14[16384];
	float 	fConst36;
	int 	iConst37;
	float 	fVec15[2048];
	int 	iConst38;
	float 	fRec32[2];
	float 	fRec39[2];
	float 	fConst39;
	float 	fConst40;
	float 	fRec38[2];
	float 	fVec16[16384];
	float 	fConst41;
	int 	iConst42;
	float 	fVec17[1024];
	int 	iConst43;
	float 	fRec36[2];
	float 	fRec0[3];
	float 	fRec1[3];
	float 	fRec2[3];
	float 	fRec3[3];
	float 	fRec4[3];
	float 	fRec5[3];
	float 	fRec6[3];
	float 	fRec7[3];
  public:
	static void metadata(Meta* m) 	{ 
		m->declare("filter.lib/name", "Faust Filter Library");
		m->declare("filter.lib/author", "Julius O. Smith (jos at ccrma.stanford.edu)");
		m->declare("filter.lib/copyright", "Julius O. Smith III");
		m->declare("filter.lib/version", "1.29");
		m->declare("filter.lib/license", "STK-4.3");
		m->declare("filter.lib/reference", "https://ccrma.stanford.edu/~jos/filters/");
		m->declare("music.lib/author", "GRAME");
		m->declare("music.lib/name", "Music Library");
		m->declare("music.lib/copyright", "GRAME");
		m->declare("music.lib/version", "1.0");
		m->declare("music.lib/license", "LGPL with exception");
		m->declare("math.lib/name", "Math Library");
		m->declare("math.lib/author", "GRAME");
		m->declare("math.lib/copyright", "GRAME");
		m->declare("math.lib/version", "1.0");
		m->declare("math.lib/license", "LGPL with exception");
	}

	virtual int getNumInputs() 	{ return 2; }
	virtual int getNumOutputs() 	{ return 2; }
	static void classInit(int samplingFreq) {
	}
	virtual void instanceInit(int samplingFreq) {
		fSamplingFreq = samplingFreq;
		fslider0 = 2e+02f;
		iConst0 = min(192000, max(1, fSamplingFreq));
		fConst1 = (3.141592653589793f / float(iConst0));
		for (int i=0; i<2; i++) fRec11[i] = 0;
		fslider1 = 2.0f;
		fConst2 = floorf((0.5f + (0.174713f * iConst0)));
		fConst3 = ((0 - (6.907755278982138f * fConst2)) / float(iConst0));
		fslider2 = 3.0f;
		fslider3 = 6e+03f;
		fConst4 = (6.283185307179586f / float(iConst0));
		for (int i=0; i<2; i++) fRec10[i] = 0;
		IOTA = 0;
		for (int i=0; i<8192; i++) fVec0[i] = 0;
		fConst5 = floorf((0.5f + (0.022904f * iConst0)));
		iConst6 = int((int((fConst2 - fConst5)) & 8191));
		for (int i=0; i<8192; i++) fVec1[i] = 0;
		fslider4 = 0.0f;
		fConst7 = (0.001f * iConst0);
		for (int i=0; i<2048; i++) fVec2[i] = 0;
		iConst8 = int((int((fConst5 - 1)) & 2047));
		for (int i=0; i<2; i++) fRec8[i] = 0;
		for (int i=0; i<2; i++) fRec15[i] = 0;
		fConst9 = floorf((0.5f + (0.153129f * iConst0)));
		fConst10 = ((0 - (6.907755278982138f * fConst9)) / float(iConst0));
		for (int i=0; i<2; i++) fRec14[i] = 0;
		for (int i=0; i<8192; i++) fVec3[i] = 0;
		fConst11 = floorf((0.5f + (0.020346f * iConst0)));
		iConst12 = int((int((fConst9 - fConst11)) & 8191));
		for (int i=0; i<1024; i++) fVec4[i] = 0;
		iConst13 = int((int((fConst11 - 1)) & 1023));
		for (int i=0; i<2; i++) fRec12[i] = 0;
		for (int i=0; i<2; i++) fRec19[i] = 0;
		fConst14 = floorf((0.5f + (0.127837f * iConst0)));
		fConst15 = ((0 - (6.907755278982138f * fConst14)) / float(iConst0));
		for (int i=0; i<2; i++) fRec18[i] = 0;
		for (int i=0; i<8192; i++) fVec5[i] = 0;
		fConst16 = floorf((0.5f + (0.031604f * iConst0)));
		iConst17 = int((int((fConst14 - fConst16)) & 8191));
		for (int i=0; i<2048; i++) fVec6[i] = 0;
		iConst18 = int((int((fConst16 - 1)) & 2047));
		for (int i=0; i<2; i++) fRec16[i] = 0;
		for (int i=0; i<2; i++) fRec23[i] = 0;
		fConst19 = floorf((0.5f + (0.125f * iConst0)));
		fConst20 = ((0 - (6.907755278982138f * fConst19)) / float(iConst0));
		for (int i=0; i<2; i++) fRec22[i] = 0;
		for (int i=0; i<8192; i++) fVec7[i] = 0;
		fConst21 = floorf((0.5f + (0.013458f * iConst0)));
		iConst22 = int((int((fConst19 - fConst21)) & 8191));
		for (int i=0; i<1024; i++) fVec8[i] = 0;
		iConst23 = int((int((fConst21 - 1)) & 1023));
		for (int i=0; i<2; i++) fRec20[i] = 0;
		for (int i=0; i<2; i++) fRec27[i] = 0;
		fConst24 = floorf((0.5f + (0.210389f * iConst0)));
		fConst25 = ((0 - (6.907755278982138f * fConst24)) / float(iConst0));
		for (int i=0; i<2; i++) fRec26[i] = 0;
		for (int i=0; i<16384; i++) fVec9[i] = 0;
		fConst26 = floorf((0.5f + (0.024421f * iConst0)));
		iConst27 = int((int((fConst24 - fConst26)) & 16383));
		for (int i=0; i<8192; i++) fVec10[i] = 0;
		for (int i=0; i<2048; i++) fVec11[i] = 0;
		iConst28 = int((int((fConst26 - 1)) & 2047));
		for (int i=0; i<2; i++) fRec24[i] = 0;
		for (int i=0; i<2; i++) fRec31[i] = 0;
		fConst29 = floorf((0.5f + (0.192303f * iConst0)));
		fConst30 = ((0 - (6.907755278982138f * fConst29)) / float(iConst0));
		for (int i=0; i<2; i++) fRec30[i] = 0;
		for (int i=0; i<8192; i++) fVec12[i] = 0;
		fConst31 = floorf((0.5f + (0.029291f * iConst0)));
		iConst32 = int((int((fConst29 - fConst31)) & 8191));
		for (int i=0; i<2048; i++) fVec13[i] = 0;
		iConst33 = int((int((fConst31 - 1)) & 2047));
		for (int i=0; i<2; i++) fRec28[i] = 0;
		for (int i=0; i<2; i++) fRec35[i] = 0;
		fConst34 = floorf((0.5f + (0.256891f * iConst0)));
		fConst35 = ((0 - (6.907755278982138f * fConst34)) / float(iConst0));
		for (int i=0; i<2; i++) fRec34[i] = 0;
		for (int i=0; i<16384; i++) fVec14[i] = 0;
		fConst36 = floorf((0.5f + (0.027333f * iConst0)));
		iConst37 = int((int((fConst34 - fConst36)) & 16383));
		for (int i=0; i<2048; i++) fVec15[i] = 0;
		iConst38 = int((int((fConst36 - 1)) & 2047));
		for (int i=0; i<2; i++) fRec32[i] = 0;
		for (int i=0; i<2; i++) fRec39[i] = 0;
		fConst39 = floorf((0.5f + (0.219991f * iConst0)));
		fConst40 = ((0 - (6.907755278982138f * fConst39)) / float(iConst0));
		for (int i=0; i<2; i++) fRec38[i] = 0;
		for (int i=0; i<16384; i++) fVec16[i] = 0;
		fConst41 = floorf((0.5f + (0.019123f * iConst0)));
		iConst42 = int((int((fConst39 - fConst41)) & 16383));
		for (int i=0; i<1024; i++) fVec17[i] = 0;
		iConst43 = int((int((fConst41 - 1)) & 1023));
		for (int i=0; i<2; i++) fRec36[i] = 0;
		for (int i=0; i<3; i++) fRec0[i] = 0;
		for (int i=0; i<3; i++) fRec1[i] = 0;
		for (int i=0; i<3; i++) fRec2[i] = 0;
		for (int i=0; i<3; i++) fRec3[i] = 0;
		for (int i=0; i<3; i++) fRec4[i] = 0;
		for (int i=0; i<3; i++) fRec5[i] = 0;
		for (int i=0; i<3; i++) fRec6[i] = 0;
		for (int i=0; i<3; i++) fRec7[i] = 0;
	}
	virtual void init(int samplingFreq) {
		classInit(samplingFreq);
		instanceInit(samplingFreq);
	}
	virtual void buildUserInterface(UI* faust_interface) {
		faust_interface->declare(0, "0", "");
		faust_interface->declare(0, "tooltip", "~ ZITA REV1 FEEDBACK DELAY NETWORK (FDN) & SCHROEDER ALLPASS-COMB REVERBERATOR (8x8). See Faust's effect.lib for documentation and references");
		faust_interface->openHorizontalBox("Zita_Rev1");
		faust_interface->declare(0, "1", "");
		faust_interface->openHorizontalBox("Input");
		faust_interface->declare(&fslider4, "1", "");
		faust_interface->declare(&fslider4, "style", "knob");
		faust_interface->declare(&fslider4, "tooltip", "Delay in ms before reverberation begins");
		faust_interface->declare(&fslider4, "unit", "ms");
		faust_interface->addVerticalSlider("In Delay", &fslider4, 0.0f, 0.0f, 1e+02f, 1.0f);
		faust_interface->closeBox();
		faust_interface->declare(0, "2", "");
		faust_interface->openHorizontalBox("Decay Times in Bands (see tooltips)");
		faust_interface->declare(&fslider0, "1", "");
		faust_interface->declare(&fslider0, "style", "knob");
		faust_interface->declare(&fslider0, "tooltip", "Crossover frequency (Hz) separating low and middle frequencies");
		faust_interface->declare(&fslider0, "unit", "Hz");
		faust_interface->addVerticalSlider("LF X", &fslider0, 2e+02f, 5e+01f, 1e+03f, 1.0f);
		faust_interface->declare(&fslider2, "2", "");
		faust_interface->declare(&fslider2, "style", "knob");
		faust_interface->declare(&fslider2, "tooltip", "T60 = time (in seconds) to decay 60dB in low-frequency band");
		faust_interface->declare(&fslider2, "unit", "s");
		faust_interface->addVerticalSlider("Low RT60", &fslider2, 3.0f, 1.0f, 8.0f, 0.1f);
		faust_interface->declare(&fslider1, "3", "");
		faust_interface->declare(&fslider1, "style", "knob");
		faust_interface->declare(&fslider1, "tooltip", "T60 = time (in seconds) to decay 60dB in middle band");
		faust_interface->declare(&fslider1, "unit", "s");
		faust_interface->addVerticalSlider("Mid RT60", &fslider1, 2.0f, 1.0f, 8.0f, 0.1f);
		faust_interface->declare(&fslider3, "4", "");
		faust_interface->declare(&fslider3, "style", "knob");
		faust_interface->declare(&fslider3, "tooltip", "Frequency (Hz) at which the high-frequency T60 is half the middle-band's T60");
		faust_interface->declare(&fslider3, "unit", "Hz");
		faust_interface->addVerticalSlider("HF Damping", &fslider3, 6e+03f, 1.5e+03f, 2.352e+04f, 1.0f);
		faust_interface->closeBox();
		faust_interface->closeBox();
	}
	virtual void compute (int count, FAUSTFLOAT** input, FAUSTFLOAT** output) {
		float 	fSlow0 = (1.0f / tanf((fConst1 * float(fslider0))));
		float 	fSlow1 = (1 + fSlow0);
		float 	fSlow2 = (1.0f / fSlow1);
		float 	fSlow3 = (0 - ((1 - fSlow0) / fSlow1));
		float 	fSlow4 = float(fslider1);
		float 	fSlow5 = expf((fConst3 / fSlow4));
		float 	fSlow6 = float(fslider2);
		float 	fSlow7 = ((expf((fConst3 / fSlow6)) / fSlow5) - 1);
		float 	fSlow8 = faustpower<2>(fSlow5);
		float 	fSlow9 = (1.0f - fSlow8);
		float 	fSlow10 = cosf((fConst4 * float(fslider3)));
		float 	fSlow11 = (1.0f - (fSlow10 * fSlow8));
		float 	fSlow12 = (fSlow11 / fSlow9);
		float 	fSlow13 = sqrtf(max((float)0, ((faustpower<2>(fSlow11) / faustpower<2>(fSlow9)) - 1.0f)));
		float 	fSlow14 = (fSlow5 * ((1.0f + fSlow13) - fSlow12));
		float 	fSlow15 = (fSlow12 - fSlow13);
		int 	iSlow16 = int((int((fConst7 * float(fslider4))) & 8191));
		float 	fSlow17 = expf((fConst10 / fSlow4));
		float 	fSlow18 = ((expf((fConst10 / fSlow6)) / fSlow17) - 1);
		float 	fSlow19 = faustpower<2>(fSlow17);
		float 	fSlow20 = (1.0f - fSlow19);
		float 	fSlow21 = (1.0f - (fSlow10 * fSlow19));
		float 	fSlow22 = (fSlow21 / fSlow20);
		float 	fSlow23 = sqrtf(max((float)0, ((faustpower<2>(fSlow21) / faustpower<2>(fSlow20)) - 1.0f)));
		float 	fSlow24 = (fSlow17 * ((1.0f + fSlow23) - fSlow22));
		float 	fSlow25 = (fSlow22 - fSlow23);
		float 	fSlow26 = expf((fConst15 / fSlow4));
		float 	fSlow27 = ((expf((fConst15 / fSlow6)) / fSlow26) - 1);
		float 	fSlow28 = faustpower<2>(fSlow26);
		float 	fSlow29 = (1.0f - fSlow28);
		float 	fSlow30 = (1.0f - (fSlow10 * fSlow28));
		float 	fSlow31 = (fSlow30 / fSlow29);
		float 	fSlow32 = sqrtf(max((float)0, ((faustpower<2>(fSlow30) / faustpower<2>(fSlow29)) - 1.0f)));
		float 	fSlow33 = (fSlow26 * ((1.0f + fSlow32) - fSlow31));
		float 	fSlow34 = (fSlow31 - fSlow32);
		float 	fSlow35 = expf((fConst20 / fSlow4));
		float 	fSlow36 = ((expf((fConst20 / fSlow6)) / fSlow35) - 1);
		float 	fSlow37 = faustpower<2>(fSlow35);
		float 	fSlow38 = (1.0f - fSlow37);
		float 	fSlow39 = (1.0f - (fSlow10 * fSlow37));
		float 	fSlow40 = (fSlow39 / fSlow38);
		float 	fSlow41 = sqrtf(max((float)0, ((faustpower<2>(fSlow39) / faustpower<2>(fSlow38)) - 1.0f)));
		float 	fSlow42 = (fSlow35 * ((1.0f + fSlow41) - fSlow40));
		float 	fSlow43 = (fSlow40 - fSlow41);
		float 	fSlow44 = expf((fConst25 / fSlow4));
		float 	fSlow45 = ((expf((fConst25 / fSlow6)) / fSlow44) - 1);
		float 	fSlow46 = faustpower<2>(fSlow44);
		float 	fSlow47 = (1.0f - fSlow46);
		float 	fSlow48 = (1.0f - (fSlow10 * fSlow46));
		float 	fSlow49 = (fSlow48 / fSlow47);
		float 	fSlow50 = sqrtf(max((float)0, ((faustpower<2>(fSlow48) / faustpower<2>(fSlow47)) - 1.0f)));
		float 	fSlow51 = (fSlow44 * ((1.0f + fSlow50) - fSlow49));
		float 	fSlow52 = (fSlow49 - fSlow50);
		float 	fSlow53 = expf((fConst30 / fSlow4));
		float 	fSlow54 = ((expf((fConst30 / fSlow6)) / fSlow53) - 1);
		float 	fSlow55 = faustpower<2>(fSlow53);
		float 	fSlow56 = (1.0f - fSlow55);
		float 	fSlow57 = (1.0f - (fSlow10 * fSlow55));
		float 	fSlow58 = (fSlow57 / fSlow56);
		float 	fSlow59 = sqrtf(max((float)0, ((faustpower<2>(fSlow57) / faustpower<2>(fSlow56)) - 1.0f)));
		float 	fSlow60 = (fSlow53 * ((1.0f + fSlow59) - fSlow58));
		float 	fSlow61 = (fSlow58 - fSlow59);
		float 	fSlow62 = expf((fConst35 / fSlow4));
		float 	fSlow63 = ((expf((fConst35 / fSlow6)) / fSlow62) - 1);
		float 	fSlow64 = faustpower<2>(fSlow62);
		float 	fSlow65 = (1.0f - fSlow64);
		float 	fSlow66 = (1.0f - (fSlow10 * fSlow64));
		float 	fSlow67 = (fSlow66 / fSlow65);
		float 	fSlow68 = sqrtf(max((float)0, ((faustpower<2>(fSlow66) / faustpower<2>(fSlow65)) - 1.0f)));
		float 	fSlow69 = (fSlow62 * ((1.0f + fSlow68) - fSlow67));
		float 	fSlow70 = (fSlow67 - fSlow68);
		float 	fSlow71 = expf((fConst40 / fSlow4));
		float 	fSlow72 = ((expf((fConst40 / fSlow6)) / fSlow71) - 1);
		float 	fSlow73 = faustpower<2>(fSlow71);
		float 	fSlow74 = (1.0f - fSlow73);
		float 	fSlow75 = (1.0f - (fSlow73 * fSlow10));
		float 	fSlow76 = (fSlow75 / fSlow74);
		float 	fSlow77 = sqrtf(max((float)0, ((faustpower<2>(fSlow75) / faustpower<2>(fSlow74)) - 1.0f)));
		float 	fSlow78 = (fSlow71 * ((1.0f + fSlow77) - fSlow76));
		float 	fSlow79 = (fSlow76 - fSlow77);
		FAUSTFLOAT* input0 = input[0];
		FAUSTFLOAT* input1 = input[1];
		FAUSTFLOAT* output0 = output[0];
		FAUSTFLOAT* output1 = output[1];
		for (int i=0; i<count; i++) {
			fRec11[0] = ((fSlow3 * fRec11[1]) + (fSlow2 * (fRec4[1] + fRec4[2])));
			fRec10[0] = ((fSlow15 * fRec10[1]) + (fSlow14 * (fRec4[1] + (fSlow7 * fRec11[0]))));
			fVec0[IOTA&8191] = (1e-20f + (0.35355339059327373f * fRec10[0]));
			fVec1[IOTA&8191] = (float)input0[i];
			float fTemp0 = (0.3f * fVec1[(IOTA-iSlow16)&8191]);
			float fTemp1 = ((fTemp0 + fVec0[(IOTA-iConst6)&8191]) - (0.6f * fRec8[1]));
			fVec2[IOTA&2047] = fTemp1;
			fRec8[0] = fVec2[(IOTA-iConst8)&2047];
			float 	fRec9 = (0.6f * fVec2[IOTA&2047]);
			fRec15[0] = ((fSlow3 * fRec15[1]) + (fSlow2 * (fRec0[1] + fRec0[2])));
			fRec14[0] = ((fSlow25 * fRec14[1]) + (fSlow24 * (fRec0[1] + (fSlow18 * fRec15[0]))));
			fVec3[IOTA&8191] = (1e-20f + (0.35355339059327373f * fRec14[0]));
			float fTemp2 = ((fVec3[(IOTA-iConst12)&8191] + fTemp0) - (0.6f * fRec12[1]));
			fVec4[IOTA&1023] = fTemp2;
			fRec12[0] = fVec4[(IOTA-iConst13)&1023];
			float 	fRec13 = (0.6f * fVec4[IOTA&1023]);
			float fTemp3 = (fRec13 + fRec9);
			fRec19[0] = ((fSlow3 * fRec19[1]) + (fSlow2 * (fRec2[1] + fRec2[2])));
			fRec18[0] = ((fSlow34 * fRec18[1]) + (fSlow33 * (fRec2[1] + (fSlow27 * fRec19[0]))));
			fVec5[IOTA&8191] = (1e-20f + (0.35355339059327373f * fRec18[0]));
			float fTemp4 = (fVec5[(IOTA-iConst17)&8191] - (fTemp0 + (0.6f * fRec16[1])));
			fVec6[IOTA&2047] = fTemp4;
			fRec16[0] = fVec6[(IOTA-iConst18)&2047];
			float 	fRec17 = (0.6f * fVec6[IOTA&2047]);
			fRec23[0] = ((fSlow3 * fRec23[1]) + (fSlow2 * (fRec6[1] + fRec6[2])));
			fRec22[0] = ((fSlow43 * fRec22[1]) + (fSlow42 * (fRec6[1] + (fSlow36 * fRec23[0]))));
			fVec7[IOTA&8191] = (1e-20f + (0.35355339059327373f * fRec22[0]));
			float fTemp5 = (fVec7[(IOTA-iConst22)&8191] - (fTemp0 + (0.6f * fRec20[1])));
			fVec8[IOTA&1023] = fTemp5;
			fRec20[0] = fVec8[(IOTA-iConst23)&1023];
			float 	fRec21 = (0.6f * fVec8[IOTA&1023]);
			float fTemp6 = (fRec21 + (fRec17 + fTemp3));
			fRec27[0] = ((fSlow3 * fRec27[1]) + (fSlow2 * (fRec1[1] + fRec1[2])));
			fRec26[0] = ((fSlow52 * fRec26[1]) + (fSlow51 * (fRec1[1] + (fSlow45 * fRec27[0]))));
			fVec9[IOTA&16383] = (1e-20f + (0.35355339059327373f * fRec26[0]));
			fVec10[IOTA&8191] = (float)input1[i];
			float fTemp7 = (0.3f * fVec10[(IOTA-iSlow16)&8191]);
			float fTemp8 = (fTemp7 + ((0.6f * fRec24[1]) + fVec9[(IOTA-iConst27)&16383]));
			fVec11[IOTA&2047] = fTemp8;
			fRec24[0] = fVec11[(IOTA-iConst28)&2047];
			float 	fRec25 = (0 - (0.6f * fVec11[IOTA&2047]));
			fRec31[0] = ((fSlow3 * fRec31[1]) + (fSlow2 * (fRec5[1] + fRec5[2])));
			fRec30[0] = ((fSlow61 * fRec30[1]) + (fSlow60 * (fRec5[1] + (fSlow54 * fRec31[0]))));
			fVec12[IOTA&8191] = (1e-20f + (0.35355339059327373f * fRec30[0]));
			float fTemp9 = (fVec12[(IOTA-iConst32)&8191] + (fTemp7 + (0.6f * fRec28[1])));
			fVec13[IOTA&2047] = fTemp9;
			fRec28[0] = fVec13[(IOTA-iConst33)&2047];
			float 	fRec29 = (0 - (0.6f * fVec13[IOTA&2047]));
			fRec35[0] = ((fSlow3 * fRec35[1]) + (fSlow2 * (fRec3[1] + fRec3[2])));
			fRec34[0] = ((fSlow70 * fRec34[1]) + (fSlow69 * (fRec3[1] + (fSlow63 * fRec35[0]))));
			fVec14[IOTA&16383] = (1e-20f + (0.35355339059327373f * fRec34[0]));
			float fTemp10 = (((0.6f * fRec32[1]) + fVec14[(IOTA-iConst37)&16383]) - fTemp7);
			fVec15[IOTA&2047] = fTemp10;
			fRec32[0] = fVec15[(IOTA-iConst38)&2047];
			float 	fRec33 = (0 - (0.6f * fVec15[IOTA&2047]));
			fRec39[0] = ((fSlow3 * fRec39[1]) + (fSlow2 * (fRec7[1] + fRec7[2])));
			fRec38[0] = ((fSlow79 * fRec38[1]) + (fSlow78 * (fRec7[1] + (fSlow72 * fRec39[0]))));
			fVec16[IOTA&16383] = (1e-20f + (0.35355339059327373f * fRec38[0]));
			float fTemp11 = (((0.6f * fRec36[1]) + fVec16[(IOTA-iConst42)&16383]) - fTemp7);
			fVec17[IOTA&1023] = fTemp11;
			fRec36[0] = fVec17[(IOTA-iConst43)&1023];
			float 	fRec37 = (0 - (0.6f * fVec17[IOTA&1023]));
			fRec0[0] = (fRec36[1] + (fRec32[1] + (fRec28[1] + (fRec24[1] + (fRec20[1] + (fRec16[1] + (fRec8[1] + (fRec12[1] + (fRec37 + (fRec33 + (fRec29 + (fRec25 + fTemp6))))))))))));
			fRec1[0] = (0 - ((fRec36[1] + (fRec32[1] + (fRec28[1] + (fRec24[1] + (fRec37 + (fRec33 + (fRec25 + fRec29))))))) - (fRec20[1] + (fRec16[1] + (fRec8[1] + (fRec12[1] + fTemp6))))));
			float fTemp12 = (fRec17 + fRec21);
			fRec2[0] = (0 - ((fRec36[1] + (fRec32[1] + (fRec20[1] + (fRec16[1] + (fRec37 + (fRec33 + fTemp12)))))) - (fRec28[1] + (fRec24[1] + (fRec8[1] + (fRec12[1] + (fRec29 + (fRec25 + fTemp3))))))));
			fRec3[0] = (0 - ((fRec28[1] + (fRec24[1] + (fRec20[1] + (fRec16[1] + (fRec29 + (fRec25 + fTemp12)))))) - (fRec36[1] + (fRec32[1] + (fRec8[1] + (fRec12[1] + (fRec37 + (fRec33 + fTemp3))))))));
			float fTemp13 = (fRec13 + fRec17);
			float fTemp14 = (fRec9 + fRec21);
			fRec4[0] = (0 - ((fRec36[1] + (fRec28[1] + (fRec20[1] + (fRec8[1] + (fRec37 + (fRec29 + fTemp14)))))) - (fRec32[1] + (fRec24[1] + (fRec16[1] + (fRec12[1] + (fRec33 + (fRec25 + fTemp13))))))));
			fRec5[0] = (0 - ((fRec32[1] + (fRec24[1] + (fRec20[1] + (fRec8[1] + (fRec33 + (fRec25 + fTemp14)))))) - (fRec36[1] + (fRec28[1] + (fRec16[1] + (fRec12[1] + (fRec37 + (fRec29 + fTemp13))))))));
			float fTemp15 = (fRec13 + fRec21);
			float fTemp16 = (fRec9 + fRec17);
			fRec6[0] = (0 - ((fRec32[1] + (fRec28[1] + (fRec16[1] + (fRec8[1] + (fRec33 + (fRec29 + fTemp16)))))) - (fRec36[1] + (fRec24[1] + (fRec20[1] + (fRec12[1] + (fRec37 + (fRec25 + fTemp15))))))));
			fRec7[0] = (0 - ((fRec36[1] + (fRec24[1] + (fRec16[1] + (fRec8[1] + (fRec37 + (fRec25 + fTemp16)))))) - (fRec32[1] + (fRec28[1] + (fRec20[1] + (fRec12[1] + (fRec33 + (fRec29 + fTemp15))))))));
			output0[i] = (FAUSTFLOAT)(0.37f * (fRec1[0] + fRec2[0]));
			output1[i] = (FAUSTFLOAT)(0.37f * (fRec1[0] - fRec2[0]));
			// post processing
			fRec7[2] = fRec7[1]; fRec7[1] = fRec7[0];
			fRec6[2] = fRec6[1]; fRec6[1] = fRec6[0];
			fRec5[2] = fRec5[1]; fRec5[1] = fRec5[0];
			fRec4[2] = fRec4[1]; fRec4[1] = fRec4[0];
			fRec3[2] = fRec3[1]; fRec3[1] = fRec3[0];
			fRec2[2] = fRec2[1]; fRec2[1] = fRec2[0];
			fRec1[2] = fRec1[1]; fRec1[1] = fRec1[0];
			fRec0[2] = fRec0[1]; fRec0[1] = fRec0[0];
			fRec36[1] = fRec36[0];
			fRec38[1] = fRec38[0];
			fRec39[1] = fRec39[0];
			fRec32[1] = fRec32[0];
			fRec34[1] = fRec34[0];
			fRec35[1] = fRec35[0];
			fRec28[1] = fRec28[0];
			fRec30[1] = fRec30[0];
			fRec31[1] = fRec31[0];
			fRec24[1] = fRec24[0];
			fRec26[1] = fRec26[0];
			fRec27[1] = fRec27[0];
			fRec20[1] = fRec20[0];
			fRec22[1] = fRec22[0];
			fRec23[1] = fRec23[0];
			fRec16[1] = fRec16[0];
			fRec18[1] = fRec18[0];
			fRec19[1] = fRec19[0];
			fRec12[1] = fRec12[0];
			fRec14[1] = fRec14[0];
			fRec15[1] = fRec15[0];
			fRec8[1] = fRec8[0];
			IOTA = IOTA+1;
			fRec10[1] = fRec10[0];
			fRec11[1] = fRec11[0];
		}
	}
};




#include "Faust_plugins_template2.cpp"

