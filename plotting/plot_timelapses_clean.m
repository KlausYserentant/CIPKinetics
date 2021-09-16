%% specify inputs
resDir = '';
logDir = '';
exps = {''};
ids = {''};


colors = {'red','green','blue','black','cyan','magenta','#4DBEEE'};
threshold = 0.75;


%% import single-cell trajectories
files = struct([]);
for j=1:numel(exps)
    % time lag between CID addition and start of timelapse. Used to update tRel
    if contains(exps{j},'MZI')
        deltaT = 2;
    else
        deltaT = 4;
    end
    % import data
    files = [files,importCIDtimecourse(resDir,logDir,exps(j),deltaT)];    
end

%% compute intensity vs. time trace
for j=1:numel(files)
    data = files(j).data;
 
    files(j).mito_area_rel = (data.area_mito(1)/data.area_cyto(1))/(data.area_mito(2)/data.area_cyto(2));
    files(j).mito_area = data.area_mito(1)/data.area_cyto(1);
 
    % Bleach-corrected mito to cyto ratio normalized to t0 and tend
    bleach_corr = data.fullframe_488nm/data.fullframe_488nm(1);
    ratio = (data.ff_488nm_mito./bleach_corr)./(data.ff_488nm_cyto./bleach_corr);
    trace = (ratio-ratio(1))./(ratio(end)-ratio(1));
    files(j).trace = trace;
       
    % compute time to threshold
    k=1;
    while k<=numel(files(j).trace) && files(j).trace(k)<threshold
        k = k+1;
    end
    if k<numel(files(j).trace)
        files(j).ttt = files(j).timeRel(k);
    else
        files(j).ttt = NaN;
    end
end

%% plot single-cell trajectories for each CID
for j=1:numel(ids)
    labels = cell.empty(0);
    selection = contains({files(:).name},ids{j});
    temp = files(selection);
    figure(j)
    title(ids{j}(1:end))
    cla
    hold on
    for k=1:sum(selection)
        time = temp(k).timeRel;
        %time = [1:122];
        plot(time(1:end-5),temp(k).trace(1:end-5))
        labels = [labels temp(k).name];
    end
    xlim([0 300]);
    ylim([-0.2 1.5]);
    
    ylabel('norm. translocation ratio')
    xlabel('time [sec]');
    legend(labels,'Interpreter', 'none');    
end

%% plot averaged trajectories
figure(numel(ids)+1)
title('Averaged single-cell trajectories')
cla
hold on
for j=1:numel(ids)
    selection = contains({files(:).name},ids{j});
    time = mean([files(selection).timeRel],2,'omitnan');    
    y = mean([files(selection).trace],2,'omitnan');
    err = std([files(selection).trace],0,2,'omitnan');
    plot(time,y-err,'LineWidth',1,'Color',colors{j})
    h(j) = plot(time,y,'LineWidth',2.5,'Color',colors{j});
    plot(time,y+err,'LineWidth',1,'Color',colors{j})
    
    mean([files(selection).ttt],2,'omitnan')
    std([files(selection).ttt],0,2,'omitnan')
    
    ids_short{j} = ids{j}(1:end);
    
end
xlim([0 300]);
ylim([-0.2 1.5]);
legend(h,ids_short)
ylabel('norm. translocation ratio');
xlabel('time [sec]');

%% boxplot time to threshold grouped per CID
ttt = double.empty(0,0);
grps = double.empty(0,0);
for j=1:numel(ids)
    selection = contains({files(:).name},ids{j});
    ttt_current = [files(selection).ttt];
    grouping = repmat(j,numel(ttt_current),1);
    ttt = [ttt,ttt_current];
    grps = [grps;grouping];
end

boxplot(ttt',grps,'Labels',ids);
figure()
title('t0.75')
cla
hold on
scatter(grps,ttt,105,'o','jitter', 'on','jitterAmount',0.2,'MarkerFaceColor','red')
ylabel('time to t0.75 [sec]');
ylim([0 200])
width = 800;
height = 500;
set(gcf,'units','points','position',[200,200,width,height])


%% superplot time to threshold grouped per CID & experiment
data_tmp = cell(0,0);
for j=1:numel(ids)
    ids(j)
    selection = contains({files(:).name},ids{j});
    data_tmp{j} = [files(selection)];
end

superplot(data_tmp,'ttt','expid',ids)
ylim([-50 800])
