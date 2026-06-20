%{
 * =============================================================================
 * Voltage Signature CNN Trainer -- Attack Detection Model Training Pipeline
 * =============================================================================
 *
 * PURPOSE:
 *   This MATLAB script trains a 1D Convolutional Neural Network (CNN) to
 *   classify voltage-signature patterns collected from IoT sensor nodes
 *   under various attack conditions (CCA, PDA, DoS, MIM, and combinations).
 *
 *   The model learns to distinguish between normal operation and different
 *   attack permutations based on raw voltage readings, enabling automated attack detection.
 *
 * DATASET STRUCTURE:
 *   - Input: Raw voltage readings (60 samples per recording, 1D time series)
 *   - Classes: 16 categories (1 Normal + 15 attack permutations)
 *   - Format: CSV/table with 60 voltage columns + 1 attackType column
 *
 * DATA SPLIT STRATEGY:
 *   1. First split (40/60):  40% test, 60% training+validation
 *   2. Second split (10/90): 10% validation, 50% training (of the 60%)
 *   Final breakdown:
 *     - Training:   50% of original data
 *     - Validation: 10% of original data
 *     - Test:       40% of original data
 *
 * MODEL ARCHITECTURE:
 *   The network is a lightweight 1D CNN optimized for edge deployment:
 *   - 5 convolutional blocks (32 → 64 → 128 → 256 → 512 filters)
 *   - Batch normalization after each conv layer for stability
 *   - NO max pooling (retains full temporal resolution of 60 samples)
 *   - Global average pooling (dimension reduction without data loss)
 *   - 2 fully connected layers with dropout (L2 regularization)
 *   - 1 fully connected layer (size=#Outputclasses=16) 
 *   - Softmax output for multi-class classification
 *   
 * TRAINING STRATEGY:
 *   - Optimizer: RMSprop (adaptive learning rate)
 *   - Learning rate: 0.001 with piecewise decay (drop 50% every 25 epochs)
 *   - Batch size: 32 (balance between stability and speed)
 *   - Max epochs: 1000 (early stopping via validation monitoring)
 *   - Regularization: Batch norm + dropout layers + frequent validation
 *
 * OUTPUT METRICS:
 *   - Overall accuracy (% correct predictions)
 *   - Per-class precision (true positives / predicted positives)
 *   - Per-class recall (true positives / actual positives)
 *   - Per-class F1 score (harmonic mean of precision & recall)
 *   - Confusion matrix visualization
 *   - Trained model saved for deployment
 * 
 * Publication Related DOIs: 
 * (10.1109/ACCESS.2025.3626798 and 10.1109/HONET67928.2025.11318504)
 * =============================================================================
%}

%% ==========================================================================
% SECTION 1: Reproducibility & Random Seed Initialization
% ==========================================================================
% Set the random seed to ensure reproducible results across runs.
% "Mersenne Twister algorithm" 
rng(42, 'twister');

%% ==========================================================================
% SECTION 2: Data Loading & Preprocessing
% ==========================================================================
% Load dataset from CSV/table file
% Expected format: 60 voltage columns + 1 'attackType' column (categorical)
dataset = readtable("EnterDatasetPath");

% Extract voltage readings (first 60 columns) and convert to numeric array
% Each row = one voltage-signature recording 
voltageReadings = table2array(dataset(:, 1:60));

% Extract attack type labels and convert to categorical for classification
attackType = categorical(dataset.attackType);

%% ==========================================================================
% SECTION 3: Train/Validation/Test Split Strategy
% ==========================================================================
% Two-level stratified partitioning to ensure balanced class distribution:

% Level 1: Split into training+validation (60%) and test set (40%)
pt1 = cvpartition(attackType, 'HoldOut', 0.4);

% Extract training+validation subset (60% of data)
temptrainingVoltageReadings = voltageReadings(training(pt1), :);
temptrainingAttackType = attackType(training(pt1), :);

% Level 2: Split the training+validation subset into training (50% of total)
% and validation (10% of total)
pt2 = cvpartition(temptrainingAttackType, 'HoldOut', 0.1);

% Final training set: 50% of original data
% Used to update network weights during training
trainingVoltageReadings = temptrainingVoltageReadings(training(pt2), :);
trainingAttackType = temptrainingAttackType(training(pt2), :);

% Final validation set: 10% of original data
% Used to monitor generalization and trigger learning rate decay
validationVoltageReadings = temptrainingVoltageReadings(test(pt2), :);
validationAttackType = temptrainingAttackType(test(pt2), :);

% Final test set: 40% of original data
% Used for final performance evaluation (held-out, never seen during training)
testVoltageReadings = voltageReadings(test(pt1), :);
testAttackType = attackType(test(pt1), :);

%% ==========================================================================
% SECTION 4: Reshape Data for CNN Input
% ==========================================================================
% CNNs expect 4D input: [height × width × channels × numSamples]
% For 1D time series: [60 × 1 × 1 × numSamples]
% - 60 = temporal dimension (voltage samples per recording)
% - 1 = spatial width (not used in 1D case)
% - 1 = number of channels (single voltage reading stream)
% - numSamples = number of recordings in the batch

% Reshape training data: (N×60) → (60×1×1×N)
trainX = reshape(trainingVoltageReadings', [60, 1, 1, size(trainingVoltageReadings, 1)]);

% Reshape validation data: (N×60) → (60×1×1×N)
valX = reshape(validationVoltageReadings', [60, 1, 1, size(validationVoltageReadings, 1)]);

% Reshape test data: (N×60) → (60×1×1×N)
testX = reshape(testVoltageReadings', [60, 1, 1, size(testVoltageReadings, 1)]);

% Determine number of attack classes from test set (should be 16: 1 Normal + 15 attacks)
numClasses = numel(unique(testAttackType));

%% ==========================================================================
% SECTION 5: Define 1D CNN Architecture
% ==========================================================================
% Lightweight CNN optimized for voltage-signature classification.
% No max pooling is used to preserve the full temporal resolution (60 samples).
% Batch normalization after each convolutional block stabilizes training.

layers = [
    % -----------------------------------------------------------------------
    % Input Layer
    % -----------------------------------------------------------------------
    % Expects 60×1×1 tensors (60 voltage samples per recording)
    % Z-score normalization
    imageInputLayer([60 1 1], 'Name', 'input', 'Normalization', 'zscore')
    
    % -----------------------------------------------------------------------
    % First Convolutional Block: Conv(32 filters) + BatchNorm + ReLU
    % -----------------------------------------------------------------------
    % 3×1 kernel: slides over temporal dimension (3 consecutive samples)
    % 32 filters: learn 32 different temporal patterns
    % 'same' padding: preserves input spatial dimensions (60 → 60)
    convolution2dLayer([3 1], 32, 'Padding', 'same', 'Name', 'conv1')
    batchNormalizationLayer('Name', 'bn1')
    reluLayer('Name', 'relu1')

    % -----------------------------------------------------------------------
    % Second Convolutional Block: Conv(64 filters) + BatchNorm + ReLU
    % -----------------------------------------------------------------------
    % 64 filters: capture more complex temporal patterns
    convolution2dLayer([3 1], 64, 'Padding', 'same', 'Name', 'conv2')
    batchNormalizationLayer('Name', 'bn2')
    reluLayer('Name', 'relu2')
    
    % -----------------------------------------------------------------------
    % Third Convolutional Block: Conv(128 filters) + BatchNorm + ReLU
    % -----------------------------------------------------------------------
    % 128 filters: deeper feature extraction
    convolution2dLayer([3 1], 128, 'Padding', 'same', 'Name', 'conv3')
    batchNormalizationLayer('Name', 'bn3')
    reluLayer('Name', 'relu3')
    
    % -----------------------------------------------------------------------
    % Fourth Convolutional Block: Conv(256 filters) + BatchNorm + ReLU
    % -----------------------------------------------------------------------
    % Deeper network for richer feature representation
    convolution2dLayer([3 1], 256, 'Padding', 'same', 'Name', 'conv4')
    batchNormalizationLayer('Name', 'bn4')
    reluLayer('Name', 'relu4')

    % -----------------------------------------------------------------------
    % Fifth Convolutional Block: Conv(512 filters) + BatchNorm + ReLU
    % -----------------------------------------------------------------------
    % Maximum filter depth for final temporal pattern extraction
    convolution2dLayer([3 1], 512, 'Padding', 'same', 'Name', 'conv5')
    batchNormalizationLayer('Name', 'bn5')
    reluLayer('Name', 'relu5')
    
    % -----------------------------------------------------------------------
    % Global Average Pooling
    % -----------------------------------------------------------------------
    % Reduces spatial dimensions (60×1×512) → (1×1×512) by averaging.
    % Advantage over flattening: much fewer parameters, reduces overfitting,
    globalAveragePooling2dLayer('Name', 'gap')
   
    % -----------------------------------------------------------------------
    % Fully Connected Block 1: FC(128) + BatchNorm + ReLU + Dropout(0.3)
    % -----------------------------------------------------------------------
    % Maps from 512 features to 128 dense features
    fullyConnectedLayer(128, 'Name', 'fc1')
    batchNormalizationLayer('Name', 'bn_fc1')
    reluLayer('Name', 'relu_fc1')
    % Dropout(0.3): randomly zero out 30% of activations during training
    % Reduces overfitting, improves generalization
    dropoutLayer(0.3, 'Name', 'dropout1')

    % -----------------------------------------------------------------------
    % Fully Connected Block 2: FC(64) + BatchNorm + ReLU + Dropout(0.4)
    % -----------------------------------------------------------------------
    % Intermediate representation (128 → 64 features)
    fullyConnectedLayer(64, 'Name', 'fc2')
    batchNormalizationLayer('Name', 'bn_fc2')
    reluLayer('Name', 'relu_fc2')
    % Dropout(0.4): higher dropout rate (40%) for additional regularization
    dropoutLayer(0.4, 'Name', 'dropout2')
    
    % -----------------------------------------------------------------------
    % Output Layer: Classification Head
    % -----------------------------------------------------------------------
    % Maps 64 features to numClasses (16 attack categories)
    fullyConnectedLayer(numClasses, 'Name', 'fc_output')
    % Softmax: converts logits to probability distribution (sums to 1)
    softmaxLayer('Name', 'softmax')
    % Classification layer: computes cross-entropy loss during training
    classificationLayer('Name', 'classification')
];

%% ==========================================================================
% SECTION 6: Specify Training Options
% ==========================================================================
% Configure the optimization algorithm and training hyperparameters.
   % Learning dynamics
   % Learning rate schedule: decay to prevent divergence in later epochs
   % Data augmentation & shuffling
   % Validation & monitoring
   % Compute environment
options = trainingOptions('rmsprop', ...
    'MaxEpochs', 1000, ...                   % Max iterations over full dataset
    'MiniBatchSize', 32, ...                 % Batch size: balance stability vs. speed
    'InitialLearnRate', 0.001, ...           % Starting learning rate
    'LearnRateSchedule', 'piecewise', ...    % Piecewise-constant decay
    'LearnRateDropFactor', 0.5, ...          % Multiply LR by 0.5 at each drop
    'LearnRateDropPeriod', 25, ...           % Drop LR every 25 epochs   
    'Shuffle', 'every-epoch', ...            % Randomize order each epoch    
    'ValidationData', {valX, validationAttackType}, ...  % Validation set
    'ValidationFrequency', 10, ...           % Check validation every 10 epochs
    'Verbose', true, ...                     % Print training progress to console
    'Plots', 'training-progress', ...        % Show real-time accuracy/loss plot
    'ExecutionEnvironment', 'gpu');          % Use GPU if available; fallback to CPU

%% ==========================================================================
% SECTION 7: Train the Network
% ==========================================================================
% Train the CNN using the training data and options specified above.
% The network learns to map voltage signatures to attack class labels.

net = trainNetwork(trainX, trainingAttackType, layers, options);

% Analyze the trained network architecture and layer connectivity
%analyzeNetwork(net);

%% ==========================================================================
% SECTION 8: Evaluate on Test Set
% ==========================================================================
% Use the trained network to classify test samples (held-out data).
% Note: Test set was never seen during training or validation.

YPred = classify(net, testX);

% Calculate overall accuracy: (correct predictions) / (total samples)
accuracy = sum(YPred == testAttackType) / numel(testAttackType);
fprintf('Test Set Accuracy: %.2f%%\n', accuracy * 100);

% Compute confusion matrix: rows = true labels, cols = predicted labels
% Diagonal elements = correct predictions per class
% Off-diagonal = misclassifications
C = confusionmat(testAttackType, YPred);

%% ==========================================================================
% SECTION 9: Calculate Per-Class Performance Metrics
% ==========================================================================
% Compute precision, recall, and F1 score for each attack class.
% These metrics are essential for understanding class-specific performance,
% especially important if some attacks are harder to detect than others.

% Overall accuracy: sum of diagonal elements / total samples
accuracy = sum(diag(C)) / sum(C(:));

% Precision per class: (true positives) / (true positives + false positives)
% Interpretation: of all samples predicted as class i, what fraction were correct?
precision = diag(C) ./ sum(C, 1)';

% Recall per class: (true positives) / (true positives + false negatives)
% Interpretation: of all samples actually class i, what fraction did we detect?
recall = diag(C) ./ sum(C, 2);

% F1 Score per class: harmonic mean of precision and recall
% Balances precision and recall into a single metric
F1_score = 2 * (precision .* recall) ./ (precision + recall);

% Display summary statistics
fprintf('\n========== PERFORMANCE METRICS ==========\n');
fprintf('Overall Accuracy: %.2f%%\n', accuracy * 100);
fprintf('Mean Precision: %.2f%%\n', mean(precision) * 100);
fprintf('Mean Recall: %.2f%%\n', mean(recall) * 100);
fprintf('Mean F1 Score: %.2f%%\n', mean(F1_score) * 100);

%% ==========================================================================
% SECTION 10: Visualization & Model Saving
% ==========================================================================
% Display confusion matrix and save trained model for deployment.

% Confusion matrix heatmap: visualize per-class performance
confusionchart(testAttackType, YPred);

% Save trained network and architecture to disk
% Used for inference
save('EnterModelSavingPath', 'net', 'layers');
fprintf('\nModel saved to: EnterModelSavingPath\n');

% ==========================================================================
% END OF DL TRAINING PIPELINE
% ==========================================================================