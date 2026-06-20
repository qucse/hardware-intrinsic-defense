%{
 * =============================================================================
 * Voltage Signature ML Classifier -- Attack Detection Model Training Pipeline
 * =============================================================================
 *
 * PURPOSE:
 *   Trains traditional ML classifiers (Bagged Ensemble, k-NN, SVM, Decision
 *   Trees, LPBoost, LDA) to detect IoT attack types from raw voltage-signature
 *   features (60 samples per record). Works directly on voltage readings without
 *   learned feature extraction.
 *
 * DATASET:
 *   - Input: 60 raw voltage readings per sample
 *   - Output: Attack class (Normal + 15 attack permutations = 16 classes)
 *   - Split: 60% training, 40% test (stratified by class)
 *
 * AVAILABLE CLASSIFIERS:
 *   1. Bagged Ensemble (DEFAULT)
 *   2. k-NN, distance-based classification
 *   3. SVM + ECOC
 *   4. Decision Tree 
 *   5. LPBoost 
 *   6. LDA  
 *
 * OUTPUT METRICS:
 *   Accuracy, precision (false alarm rate), recall (detection rate), F1 score,
 *   and confusion matrix visualization.
 *
 * Publication Related DOIs: 
 * (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504)
 * =============================================================================
%}

%% ==========================================================================
% SECTION 1: Reproducibility & Random Seed Initialization
% ==========================================================================
% Set the random seed to ensure reproducible results across runs "Mersenne Twister algorithm".
rng(42, 'twister');

%% ==========================================================================
% SECTION 2: Data Loading & Preprocessing
% ==========================================================================
% Load the voltage signature dataset from CSV/table file.
% Expected format: 60 voltage feature columns + 1 'attackType' column

% Read dataset into MATLAB table structure
% Table provides flexible column naming and type management
VoltageData = readtable('EnterDatasetPath');

% Convert attackType column to categorical for classification
% Categorical reduces memory usage and enables stratified sampling
VoltageData.attackType = categorical(VoltageData.attackType);

%% ==========================================================================
% SECTION 3: Train/Test Split
% ==========================================================================
% Stratified split: partitions data while preserving class distribution.
% This ensures both training and test sets have similar proportions of
% each attack type, which is crucial for imbalanced datasets.

% Stratified partition: 40% test, 60% training
pt = cvpartition(VoltageData.attackType, 'HoldOut', 0.4);

% Extract training set (60% of data)
% Used to fit model parameters during training
trainingSet = VoltageData(training(pt), :);

% Extract test set (40% of data)
% Held-out, never seen by model during training; used for final evaluation
testSet = VoltageData(test(pt), :);

%% ==========================================================================
% SECTION 4: Dataset Summary Statistics
% ==========================================================================
% Print summary information about dataset splits for verification.

% Total number of samples in the original dataset
fprintf('\n========== DATASET SUMMARY ==========\n');
fprintf('%s Original Observations (samples)\n', num2str(height(VoltageData)));

% Number of training samples
fprintf('%s Training Observations (samples)\n', num2str(height(trainingSet)));

% Number of test samples
fprintf('%s Testing Observations (samples)\n', num2str(height(testSet)));

% Number of unique attack classes (should be 16: 1 Normal + 15 attacks)
numClasses = numel(unique(testSet.attackType));
fprintf('%s Number of Attack Classes\n', num2str(numClasses));

%% ==========================================================================
% SECTION 5: Model Training — Classifier Selection
% ==========================================================================
% Train a classifier using the training set.
% Several algorithms are available; uncomment to switch between them.
% -----------------------------------------------------------------------
% DEFAULT: Bagged Ensemble (Recommended)
% -----------------------------------------------------------------------
% Bootstrap Aggregating (Bagging) of decision trees:
% - Trains multiple decision trees on random bootstrap samples of training data
% - Aggregates predictions via majority voting (for classification)
% - 500 learning cycles provides stable ensemble predictions
% - ClassNames parameter ensures consistent label ordering
mdl = fitcensemble(trainingSet(:, 1:60), trainingSet.attackType, ...
    'Method', 'Bag', ...                    % Bagging method
    'NumLearningCycles', 500, ...           % 500 trees in ensemble
    'ClassNames', unique(trainingSet.attackType));  % Ensure consistent class ordering

% -----------------------------------------------------------------------
% ALTERNATIVE 1: k-Nearest Neighbors (k-NN)
% -----------------------------------------------------------------------
% Uncomment to use k-NN instead of Bagging
% mdl = fitcknn(trainingSet(:, 1:60), trainingSet.attackType, ...
%     'NumNeighbors', 5, ...               % Use 5 nearest neighbors
%     'DistanceWeight', 'squaredinverse');  % Weight inversely by squared distance

% -----------------------------------------------------------------------
% ALTERNATIVE 2: Support Vector Machine (SVM) with ECOC
% -----------------------------------------------------------------------
% Uncomment to use SVM with Error-Correcting Output Code for multi-class
% t = templateSVM('KernelFunction', 'polynomial');
% mdl = fitcecoc(trainingSet(:, 1:60), trainingSet.attackType, ...
%     'Coding', 'onevsall', ...            % One-vs-All encoding
%     'Learners', t);

% -----------------------------------------------------------------------
% ALTERNATIVE 3: Decision Tree
% -----------------------------------------------------------------------
% Uncomment to use Decision Tree with pruning
% mdl = fitctree(trainingSet(:, 1:60), trainingSet.attackType, ...
%     'Prune', 'on');

% -----------------------------------------------------------------------
% ALTERNATIVE 4: LPBoost (Linear Programming Boost)
% -----------------------------------------------------------------------
% Uncomment to use adaptive boosting with linear programming
% mdl = fitcensemble(trainingSet(:, 1:60), trainingSet.attackType, ...
%     'Method', 'LPBoost');

% -----------------------------------------------------------------------
% ALTERNATIVE 5: Linear Discriminant Analysis (LDA)
% -----------------------------------------------------------------------
% Uncomment to use LDA
% mdl = fitcdiscr(trainingSet(:, 1:60), trainingSet.attackType, ...
%     'DiscrimType', 'linear');

%% ==========================================================================
% SECTION 6: Model Evaluation on Test Set
% ==========================================================================
% Apply the trained model to the held-out test set.
% Test performance indicates how the model generalizes to unseen data.

% Generate predictions for test set (first 60 columns are voltage features)
predictedTestingSamples = predict(mdl, testSet(:, 1:60));

% Compute confusion matrix: rows = true labels, columns = predicted labels
% Diagonal elements = correct predictions per class
% Off-diagonal elements = misclassifications (false positives/negatives)
C = confusionmat(testSet.attackType, predictedTestingSamples);

%% ==========================================================================
% SECTION 7: Visualization — Confusion Matrix
% ==========================================================================
% Confusion matrix heatmap: visualize per-class performance
confusionchart(testSet.attackType, predictedTestingSamples);

%% ==========================================================================
% SECTION 8: Calculate Performance Metrics
% ==========================================================================
% Compute standard classification metrics: accuracy, precision, recall, F1.
% These metrics provide different perspectives on model performance.

% Overall accuracy: proportion of correct predictions
% Formula: (true positives + true negatives) / (all predictions)
accuracy = sum(diag(C)) / sum(C(:));

% Per-class precision: proportion of positive predictions that are correct
% Formula: TP / (TP + FP)
% Interpretation: of all samples predicted as attack X, how many were correct?
% High precision = low false alarm rate (good for reducing security alerts)
precision = diag(C) ./ sum(C, 1)';

% Per-class recall: proportion of actual positives that were detected
% Formula: TP / (TP + FN)
% Interpretation: of all actual instances of attack X, how many did we detect?
% High recall = low missed detection rate (good for catching attacks)
recall = diag(C) ./ sum(C, 2);

% Per-class F1 score: harmonic mean of precision and recall
% Formula: 2 * (precision * recall) / (precision + recall)
% F1 balances precision and recall into a single metric (0 = worst, 1 = best)
% Useful when you care equally about false positives and false negatives
F1_score = 2 * (precision .* recall) ./ (precision + recall);

%% ==========================================================================
% SECTION 9: Display Performance Summary
% ==========================================================================
% Print aggregate metrics summarizing model performance.

fprintf('\n========== PERFORMANCE METRICS ==========\n');

% Print overall accuracy (simple metric: % of correct predictions)
fprintf('Overall Accuracy: %.2f%%\n', accuracy * 100);

% Print mean precision across all classes (false alarm rate)
fprintf('Mean Precision: %.2f%%\n', mean(precision) * 100);

% Print mean recall across all classes (detection rate)
fprintf('Mean Recall: %.2f%%\n', mean(recall) * 100);

% Print mean F1 score across all classes (balanced metric)
fprintf('Mean F1 Score: %.2f%%\n', mean(F1_score) * 100);

fprintf('=========================================\n');

%% ==========================================================================
% SECTION 10: Model Persistence — Save Trained Model
% ==========================================================================
% Save the trained model to disk for deployment on edge devices.
% Used for inference.

% Save model to specified file path
save('EnterModelSavingPath', 'mdl');

fprintf('\nModel successfully saved to: EnterModelSavingPath\n');

% ==========================================================================
% END OF ML TRAINING PIPELINE
% ==========================================================================
