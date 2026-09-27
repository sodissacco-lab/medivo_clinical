/// Starting text for a new topic, following the blueprint template for
/// each type of content. Authors replace the prompts in square brackets.

const String _diseaseTemplate = '''## Overview

**Definition.** [One-sentence definition.]

**Epidemiology.** [How common, who is affected, Ugandan context.]

**Aetiology.** [Causes and organisms.]

**Risk factors.** [List.]

**Pathophysiology.** [Brief mechanism.]

## Clinical features

**Symptoms.** [List.]

**Signs.** [List.]

**Red flags.** [Features that need urgent action.]

## Diagnosis

**Clinical diagnosis.** [How the diagnosis is made.]

**Differential diagnosis.** [Conditions to consider.]

**Investigations.**
- [Test and why]

## Management

**Non-pharmacological.** [Measures.]

**Pharmacological.**
- [Drug, dose, route, frequency, duration]

**Supportive treatment.** [Measures.]

## Special populations

**Paediatric.** [Differences.]

**Pregnancy.** [Differences.]

**Elderly.** [Differences.]

**Renal impairment.** [Differences.]

**Hepatic impairment.** [Differences.]

## Referral

**Emergency referral.** [When.]

**Specialist referral.** [When.]

## Patient education

- [Key message]
''';

const String _drugTemplate = '''## Overview

**Generic name.** [Name]

**Brand names.** [Common brands in Uganda]

**Drug class.** [Class]

**Pharmacological class.** [Class]

## Indications

- [Indication]

## Contraindications

- [Contraindication]

## Dosing

**Routes and formulations.** [e.g. oral tablets 250 mg, 500 mg; IV injection]

**Adult dosing.**
- [Indication: dose, route, frequency, duration]

**Paediatric dosing.**
- [Indication: mg/kg dose, frequency, maximum]

**Maximum dose.** [Adult and paediatric maximum]

## Special populations

**Pregnancy.** [Safety and advice]

**Lactation.** [Safety and advice]

**Renal adjustment.** [By creatinine clearance]

**Hepatic adjustment.** [Advice]

## Adverse effects

- [Common]
- [Serious]

## Warnings

- [Warning]

## Monitoring

- [What to monitor and when]

## Drug interactions

- [Interacting drug: effect and action]

## Storage

[Storage conditions]
''';

const String _labTemplate = '''## Overview

**What it measures.** [Description]

**Specimen.** [e.g. EDTA whole blood, 2 mL]

**Units.** [SI unit and conventional unit]

## Reference ranges

| Group | Reference range (SI) | Reference range (Conventional) |
| --- | --- | --- |
| Adult male | [range] | [range] |
| Adult female | [range] | [range] |
| Children | [age-specific ranges] | [age-specific ranges] |

## Low results

**Possible causes.**
- [Cause]

## High results

**Possible causes.**
- [Cause]

## Clinical interpretation

[How to interpret results in practice, including critical values that need urgent action.]
''';

const String _radiologyTemplate = '''## Investigation

[What the investigation is.]

## Indications

- [Indication]

## Preparation

- [Patient preparation]

## Contraindications

- [Contraindication]

## Normal findings

- [Finding]

## Common abnormal findings

- [Finding and what it suggests]

## Interpretation framework

1. [Step]

## Red flags

- [Finding needing urgent action]

## When to refer

- [Situation]
''';

const String _emergencyTemplate = '''## 1. Recognise

- [Key features]

## 2. Call for help

- [Who to call and what to prepare]

## 3. Immediate treatment

1. [Action, drug, dose, route]

## 4. Monitoring

- [What to monitor and how often]

## 5. Additional treatment

- [Further measures]

## 6. Referral

- [When and where]
''';

const String _calculatorTemplate = '''## Purpose

[What the calculator is for.]

## Inputs

- [Input and unit]

## Validation

- [Allowed range for each input]

## Formula

[The formula. The calculation itself is built as tested code, never by AI.]

## Interpretation

| Result | Meaning |
| --- | --- |
| [range] | [interpretation] |

## Reference

[Original source of the score or formula.]
''';

const String _algorithmTemplate = '''## Presenting symptom

[Symptom and who this pathway is for.]

## Assess red flags

- [Red flag] → **Emergency pathway:** [action]

## Initial investigations

- [Test]

## Differential

- [Condition]

## Confirmation

[How the diagnosis is confirmed.]

## Management

[Management, or link to the disease topic.]

## Follow-up

[When and what to review.]
''';

const String _guidelineTemplate = '''## Summary

[What the guideline is, in one or two sentences, in Medivo's own words.]

## What it covers

- [Topic]

## Who it applies to

[Setting, facility level and patient group.]

## Key recommendations

[In Medivo's own words, or quoted only where the licence allows.]

## Source

[Issuing body, edition, year.]

## Licence

[How Medivo may use it. Also fill in GUIDELINE DETAILS: official link and licence status.]
''';

const String _articleTemplate = '''## Summary

[Short summary.]

## Main text

[Article text.]

## Key points

- [Point]
''';

String templateFor(String type) => switch (type) {
      'disease' => _diseaseTemplate,
      'drug' => _drugTemplate,
      'lab_test' => _labTemplate,
      'radiology' => _radiologyTemplate,
      'emergency' => _emergencyTemplate,
      'calculator' => _calculatorTemplate,
      'algorithm' => _algorithmTemplate,
      'guideline' => _guidelineTemplate,
      _ => _articleTemplate,
    };