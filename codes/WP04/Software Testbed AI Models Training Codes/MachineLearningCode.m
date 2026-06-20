%% Reproducibility
% Set the random seed to 42 using the Mersenne Twister algorithm
rng(42, 'twister');

%% Import data:
VoltageData = readtable('EnterDatasetPath');
VoltageData.attackType = categorical(VoltageData.attackType); 

%% Split the data into training and test sets:

pt = cvpartition(VoltageData.attackType,'HoldOut',0.4); 

trainingSet = VoltageData(training(pt),:);
testSet = VoltageData(test(pt),:);

%Observation means Number of samples
disp([num2str(height(VoltageData)), ' Orginal Observation (samples)']); 
disp([num2str(height(trainingSet)), ' Training Observation (samples)']);
disp([num2str(height(testSet)), ' Testing observation (samples)']);


numClasses = numel(unique(testSet.attackType)); 
disp(numClasses);
%% Modles training
% mdl = fitcknn(trainingSet(:, 1:60),trainingSet.attackType, 'NumNeighbors', index, 'DistanceWeight','squaredinverse'); %Creating our predicition model
 mdl = fitcensemble(trainingSet(:, 1:60), trainingSet.attackType, 'Method', 'Bag', 'NumLearningCycles', 500, 'ClassNames', unique(trainingSet.attackType));
 % t=templateSVM('KernelFunction','polynomial');
 % mdl = fitcecoc(trainingSet(:, 1:60),trainingSet.attackType,'Coding','onevsall','Learners',t);%SVM
% mdl = fitctree(trainingSet(:, 1:60), trainingSet.attackType, 'Prune','on');%Decision Trees
% mdl = fitcensemble(trainingSet(:, 1:60), trainingSet.attackType, 'Method', 'LPBoost'); 
% mdl = fitcdiscr(trainingSet(:, 1:60), trainingSet.attackType, 'DiscrimType', 'linear'); 

predictedTestingSampels = predict(mdl,testSet(:,1:60));
C = confusionmat(testSet.attackType, predictedTestingSampels);
confusionchart(testSet.attackType, predictedTestingSampels)

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
fprintf('=================\n');

%% Save the model
save('EnterModelSavingPath', 'mdl');
