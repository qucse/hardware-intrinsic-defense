
%% Reproducibility
% Set the random seed to 42 using the Mersenne Twister algorithm
rng(42, 'twister');

%% This code applied on the raw voltage features with no maxpooling layer integration
dataset = readtable("EnterDatasetPath");
voltageReadings = table2array(dataset(:, 1:60)); % Convert table to array
attackType = categorical(dataset.attackType);

pt1 = cvpartition(attackType, 'HoldOut', 0.4); % 40% Test, 60% Train


temptrainingVoltageReadings = voltageReadings(training(pt1), :);
temptrainingAttackType = attackType(training(pt1), :);

pt2= cvpartition(temptrainingAttackType, 'HoldOut', 0.1); % 10% Validation, 50% Train

%Training
trainingVoltageReadings = temptrainingVoltageReadings(training(pt2), :);
trainingAttackType = temptrainingAttackType(training(pt2), :);

%Validation
validationVoltageReadings = temptrainingVoltageReadings(test(pt2), :);
validationAttackType = temptrainingAttackType(test(pt2), :);

%Testing
testVoltageReadings = voltageReadings(test(pt1), :);
testAttackType = attackType(test(pt1), :);

% Reshape training data ==> (60 voltageReadings (rows), 1 column, 1 channel, #samples )
trainX = reshape(trainingVoltageReadings', [60, 1, 1, size(trainingVoltageReadings, 1)]);
% Reshape validation data  
valX = reshape(validationVoltageReadings', [60, 1, 1, size(validationVoltageReadings, 1)]);
% Reshape test data
testX = reshape(testVoltageReadings', [60, 1, 1, size(testVoltageReadings, 1)]);

numClasses = numel(unique(testAttackType));
%% Step 2: Define the Neural Network Architecture
layers = [
   % Input layer - expects [sequenceLength × 1 × 1] per sample
    imageInputLayer([60 1 1], 'Name', 'input', 'Normalization', 'zscore')
    
    % First Convolutional Block
    convolution2dLayer([3 1], 32, 'Padding', 'same', 'Name', 'conv1')
    batchNormalizationLayer('Name', 'bn1')
    reluLayer('Name', 'relu1')
    % maxPooling2dLayer([2 1], 'Stride', [2 1], 'Name', 'pool1') % input 60 ==> 60/2 and Output: 30×1×32
    
    % Second Convolutional Block  
    convolution2dLayer([3 1], 64, 'Padding', 'same', 'Name', 'conv2')
    batchNormalizationLayer('Name', 'bn2')
    reluLayer('Name', 'relu2')
    % maxPooling2dLayer([2 1], 'Stride', [2 1], 'Name', 'pool2') % input 30 ==> 30/2  and Output: 15×1×64
    
    % Third Convolutional Block
    convolution2dLayer([3 1], 128, 'Padding', 'same', 'Name', 'conv3')
    batchNormalizationLayer('Name', 'bn3')
    reluLayer('Name', 'relu3')
    % maxPooling2dLayer([3 1], 'Stride', [3 1], 'Name', 'pool3') % input 15 ==> 15/3  Output: 5×1×128
    
    % Fourth Convolutional Block (Optional - for deeper feature extraction)
    convolution2dLayer([3 1], 256, 'Padding', 'same', 'Name', 'conv4')
    batchNormalizationLayer('Name', 'bn4')
    reluLayer('Name', 'relu4')

    % Fifth Convolutional Block (Optional - for deeper feature extraction)
    convolution2dLayer([3 1], 512, 'Padding', 'same', 'Name', 'conv5')
    batchNormalizationLayer('Name', 'bn5')
    reluLayer('Name', 'relu5')
    
    % Global Average Pooling (reduces parameters compared to flattening)
    globalAveragePooling2dLayer('Name', 'gap')
   
    % Fully Connected Layers
    fullyConnectedLayer(128, 'Name', 'fc1')
    batchNormalizationLayer('Name', 'bn_fc1')
    reluLayer('Name', 'relu_fc1')
    dropoutLayer(0.3, 'Name', 'dropout1')

    fullyConnectedLayer(64, 'Name', 'fc2')
    batchNormalizationLayer('Name', 'bn_fc2')
    reluLayer('Name', 'relu_fc2')
    dropoutLayer(0.4, 'Name', 'dropout2')
    
    % Output layer
    fullyConnectedLayer(numClasses, 'Name', 'fc_output')
    softmaxLayer('Name', 'softmax')
    classificationLayer('Name', 'classification')
];

%% Step 3: Specify Training Options
options = trainingOptions('rmsprop', ...
    'MaxEpochs', 1000, ... % Reduced epochs for CNN
    'MiniBatchSize', 32, ... % Larger batch size for CNN 
    'InitialLearnRate', 0.001, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 25, ... % More frequent LR drops
    'Shuffle', 'every-epoch', ...
    'ValidationData', {valX, validationAttackType}, ...
    'ValidationFrequency', 10, ... % More frequent validation
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'ExecutionEnvironment', 'gpu'); % Use GPU if available
%% Step 4: Train the Network
net = trainNetwork(trainX, trainingAttackType, layers, options);
analyzeNetwork(net);

YPred = classify(net, testX);

% Calculate the accuracy
accuracy = sum(YPred == testAttackType) / numel(testAttackType);
fprintf('Test Set Accuracy: %.2f%%\n', accuracy * 100);

% Calculate confusion matrix
C = confusionmat(testAttackType, YPred);

% Calculate metrics
accuracy = sum(diag(C)) / sum(C(:));
precision = diag(C) ./ sum(C, 1)';
recall = diag(C) ./ sum(C, 2);
F1_score = 2 * (precision .* recall) ./ (precision + recall);

% Display metrics
fprintf('Accuracy: %.2f%%\n', accuracy * 100);
fprintf('Precision: %.2f%%\n', mean(precision) * 100);
fprintf('Recall: %.2f%%\n', mean(recall) * 100);
fprintf('F1 Score: %.2f%%\n', mean(F1_score) * 100);

confusionchart(testAttackType, YPred)

save('EnterModelSavingPath', 'net', 'layers');
