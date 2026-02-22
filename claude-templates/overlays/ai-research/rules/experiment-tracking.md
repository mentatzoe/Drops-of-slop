---
description: Experiment tracking and reproducibility standards
paths:
  - "**/*.py"
  - "**/experiments/**/*"
  - "**/configs/**/*"
  - "**/*.ipynb"
---

# Experiment Tracking

## Reproducibility
- Log all hyperparameters, random seeds, and data splits for every experiment run
- Pin exact library versions in `requirements.txt` or `pyproject.toml`
- Use config files (YAML/TOML) for experiment parameters — never hardcode in training scripts
- Record the git commit hash with every experiment result

## Data Management
- Document dataset versions, sources, preprocessing steps, and known biases
- Never modify raw data in place — write transformations as idempotent pipeline steps
- Store data manifests (row counts, column types, sample distributions) alongside datasets
- Use DVC or similar tools for large dataset versioning

## Experiment Organization
- One directory per experiment with: config, results, logs, and a summary README
- Name experiments descriptively: `2024-03-15_bert-finetune_lr-sweep`, not `exp7`
- Compare against a documented baseline in every experiment summary
- Archive failed experiments with notes on why they failed — negative results are valuable

## Model Evaluation
- Report confidence intervals, not just point metrics
- Evaluate on held-out test sets only after development is complete
- Document evaluation metrics, their definitions, and why they were chosen
- Include qualitative error analysis alongside quantitative metrics
