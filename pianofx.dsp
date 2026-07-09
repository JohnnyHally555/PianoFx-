Import("stdfaust.lib");

// ==========================================
// CONTROLES DO PLUGIN (INTERFACE AAP / VST3)
// ==========================================

// Grupo 1: Parâmetros Base de Timbre (Metal)
tone = hslider("v:1_Timbre_Base/[0]Tone (Dark-Bright)", 0.5, 0, 1, 0.01) : si.smoo;
character = hslider("v:1_Timbre_Base/[1]Character", 0.3, 0, 1, 0.01) : si.smoo;
inharmonicity = hslider("v:1_Timbre_Base/[2]Inharmonicity", 0.15, 0, 1, 0.01) : si.smoo;
hardness = hslider("v:1_Timbre_Base/[3]Hammer Hardness", 0.5, 0, 1, 0.01) : si.smoo;
strikePoint = hslider("v:1_Timbre_Base/[4]Strike Point", 0.25, 0, 1, 0.01) : si.smoo;
unaCorda = hslider("v:1_Timbre_Base/[5]Una Corda (Soft Felt)", 0.0, 0, 1, 0.01) : si.smoo;

// Grupo 2: Acústica e Mecânica da Madeira 🪵
inertia = hslider("v:2_Acustica_Madeira/[0]Inertia (Hammer Weight)", 0.3, 0, 1, 0.01) : si.smoo;
woodRes = hslider("v:2_Acustica_Madeira/[1]Wood Resonance", 0.4, 0, 1, 0.01) : si.smoo;
mechThump = hslider("v:2_Acustica_Madeira/[2]Mechanical Thump", 0.2, 0, 1, 0.01) : si.smoo;
lidPosition = hslider("v:2_Acustica_Madeira/[3]Lid Position (0=Closed, 1=Open)", 1.0, 0, 1, 0.01) : si.smoo;

// Grupo 3: Sistema de Limpeza Dinâmica 🧼
deClick = hslider("v:3_Limpeza_Dinamica/[0]De-Click (Attack Smooth)", 0.0, 0, 1, 0.01) : si.smoo;
sampleClean = hslider("v:3_Limpeza_Dinamica/[1]Sample Clean (Dirt Reducer)", 0.0, 0, 1, 0.01) : si.smoo;

// Grupo 4: Saturação e Espaço (O Peso Analógico) 🎛️
tapeDrive = hslider("v:4_Espaco_e_Saturacao/[0]Tape Drive (Saturation)", 0.0, 0, 1, 0.01) : si.smoo;
sympRes = hslider("v:4_Espaco_e_Saturacao/[1]Sympathetic Resonance", 0.1, 0, 1, 0.01) : si.smoo;
stereoWidth = hslider("v:4_Espaco_e_Saturacao/[2]Stereo Width", 0.5, 0, 1, 0.01) : si.smoo;

// ==========================================
// BLOCOS DE PROCESSAMENTO DSP
// ==========================================

// 1. Limpeza Dinâmica
applyDeClick(s) = s : fi.lowpass(1, cutoff)
with {
    envFast = abs(s) : fi.lowpass(1, 300);
    envSlow = abs(s) : fi.lowpass(1, 15);
    transient = min(1.0, max(0, envFast - envSlow) : fi.lowpass(1, 100) * 8.0);
    cutoff = 20000 - (transient * deClick * 16500);
};

applySampleClean(s) = (s * (1.0 - blend)) + ((s : fi.lowpass(1, 2500)) * blend)
with {
    env = abs(s) : fi.lowpass(1, 10);
    gate = max(0, 1.0 - (env * 8.0));
    blend = gate * sampleClean * 0.85;
};

// 2. Modificadores de Martelo (Inércia e Una Corda)
applyHammer(s) = s : fi.lowpass(1, cutoff)
with { 
    baseCutoff = 20000 * (1.0 - (inertia * 0.7));
    cutoff = baseCutoff * (1.0 - (unaCorda * 0.6));
};

// 3. Timbre, Dureza e Inarmonicidade
applyTone(s) = s : fi.resonlp(fc, q, 1)
with {
    fc = 400 + (tone * 7000) + (hardness * 5000);
    q = 0.5 + (character * 1.5);
};

applyInharmonicity(s) = (s + ((s : de.delay(1024, dtime)) * inharmonicity)) * 0.7
with { dtime = 15 + (strikePoint * 60); };

// 4. Mecânica da Madeira (Ressonância, Thump e Tampa)
applyWood(s) = s + ((s : fi.resonbp(250, 1.2)) * woodRes * 1.4);

applyMech(s) = s + ((no.noise : fi.lowpass(1, 130) : fi.highpass(1, 50)) * env * mechThump * 0.2)
with { env = abs(s) : fi.lowpass(1, 200); };

applyLid(s) = s : fi.lowpass(1, lidFreq)
with { lidFreq = 800 + (lidPosition * 19200); };

// 5. Motor de Saturação Analógica (Tape Drive)
applyDrive(s) = ma.tanh(s * (1.0 + (tapeDrive * 3.0))) * (1.0 - (tapeDrive * 0.2));

// 6. Ressonância Simpática (Aura Fantasmagórica)
applySympRes(s) = s + ((s : re.jcrev : fi.lowpass(1, 3000)) * sympRes * 0.6);

// ==========================================
// FLUXO ESTÉREO E LARGURA (STEREO WIDTH)
// ==========================================

process(left_in, right_in) = left_out, right_out
with {
    // Processamento Mono do Corpo 
    mono_in = (left_in + right_in) * 0.5;
    mono_fx = mono_in : applyDeClick : applySampleClean : applyHammer : applyTone : applyInharmonicity : applyWood : applyMech : applyLid : applyDrive : applySympRes;
    
    // Processamento do Estéreo
    mid = mono_fx;
    side = (left_in - right_in) * 0.5 * (stereoWidth * 2.0);
    
    left_out = mid + side;
    right_out = mid - side;
};
