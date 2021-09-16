function superplot(data,var,reps,varargin)
% function to plot categorized scatter plot with origin of individual data
% points and summary statistics overlayed.
% based on Lord et al. (2019), JCB, doi: 10.1083/jcb.202001064
%%%%
% data inputs
% - data struct with fields with names specified in var and reps.
% - var will be plottedce
% - reps will be used to assign data point to experiment

% define colors
colors = {'blue','red','green','black','cyan','magenta'};
signs = {'o','s','d','^','p','>','<'};

% check size of input data
if isstruct(data)
    data = {data};
end

if numel(varargin)>0
    switch numel(varargin)
        case 1
            datalabels = varargin{1};
    end
end


%figure()
hold on
for exp=1:numel(data)
    exp
    means = [];
    
    % identify unique classifiers
    currentD = data{exp};
    if strcmp(class(currentD(1).(string(reps))),'cell')
        tmp = cellfun(@(x) x{1},{currentD(:).(string(reps))},'UniformOutput',false);
        classes = unique(tmp);
    elseif strcmp(class(currentD(1).(string(reps))),'double')
        classes = unique([currentD(:).(string(reps))]);
    else
        classes = unique({currentD(:).(string(reps))})
    end
     
    % global jitter
    jit = (exp-1)+0.8 + 0.4.*rand(numel(currentD),1);
    jit_means = (exp-1)+0.85 + 0.3.*rand(numel(classes),1);
    
    % loop over experiments
    for i=1:numel(classes)
        % filter current data points
        filter = cell2mat(cellfun(@(x) strcmp(x,classes(i)),{currentD(:).(string(reps))},'UniformOutput',false));
        
        % calculate experiment means
        vals = [currentD(filter).(string(var))];
        means(i) = mean(vals(~isnan(vals)));
        
        % plot individual data points for single exp
        scatter(jit(filter),[currentD(filter).(string(var))],120,signs{i},'MarkerFaceColor',colors{i},'MarkerEdgeColor','none')
        
        % plot mean for exp
        scatter(jit_means(i),means(i),240,signs{i},'MarkerFaceColor',colors{i},'MarkerEdgeColor','black')
    end
    
    % global mean + error
    mean_glob = mean(means)
    std_glob = std(means,0)
    l1 = line([exp-0.2,exp+0.2],[mean_glob,mean_glob],'Color','black','LineWidth',2);
    l1.Color(4) = 0.75;
    l2 = line([exp-0.1,exp+0.1],[mean_glob+std_glob,mean_glob+std_glob],'Color','black','LineWidth',2);
    l2.Color(4) = 0.75;
    l3 = line([exp-0.1,exp+0.1],[mean_glob-std_glob,mean_glob-std_glob],'Color','black','LineWidth',2);
    l3.Color(4) = 0.75;
    l4 = line([exp,exp],[mean_glob+std_glob,mean_glob-std_glob],'Color','black','LineWidth',2); 
    l4.Color(4) = 0.75;
end

if numel(varargin)>0
    xticks(linspace(1,numel(datalabels),numel(datalabels)))
    set(groot, 'DefaultAxesTickLabelInterpreter', 'none')
    xticklabels(datalabels)
end