clear
clc
fclose('all');

% data_dir = 'C:\Users\Greydon\Documents\github\afids_parkinsons\input\input_fid';
data_dir = 'D:\School\Residency\Research\FIDs Study\Github\afids_parkinsons\input\input_fid';

sub_ignore = [];

raters = dir(data_dir);
raters = raters([raters.isdir] & ~strcmp({raters.name},'.') & ~strcmp({raters.name},'..'));
df_raters = cell(1,1);
iter_cnt = 1;
for irater = 1:length(raters)
    patient_files = dir(fullfile(data_dir,raters(irater).name));
    patient_files = patient_files([patient_files.isdir] & ~strcmp({patient_files.name},'.') & ~strcmp({patient_files.name},'..'));
    for isub = 1:length(patient_files)
        fileN = dir(fullfile(data_dir,raters(irater).name, patient_files(isub).name));
        fileN = fileN(~strcmp({fileN.name},'.') & ~strcmp({fileN.name},'..'));
        [data_table] = read_fcsv(fileN, raters(irater).name, patient_files(isub).name);
        df_raters{iter_cnt} = data_table;
        iter_cnt = iter_cnt + 1;
    end
end

Data = vertcat(df_raters{:});

% List of raters
raters = string(unique(Data.rater,'rows'));

% Generates arrays for subjects completed by each rater
Sub = {};
Size_sub = [];
for r = 1:length(raters)
    idx = ismember(Data.rater, raters(r));
    sub_temp = unique(Data.subject(idx,:), 'rows');
    if ~isempty(sub_ignore)
        sub_temp = sub_temp(~ismember(sub_temp, sub_ignore));
    end
    Sub{1,r} = sub_temp(~ismember(sub_temp, sub_ignore));
    Size_sub(r) = length(Sub{1,r});
end

% Subjects completed by all raters
[B,I] = sort(Size_sub, 'descend');
Sub = Sub(I);
Sub_Comp = intersect(Sub{1,1},Sub{1,2});
for irate = 2:length(raters)
    Sub_Comp = intersect(Sub_Comp,Sub{1,irate});
end

% Table only containing subjects completed by all raters
Data_comp = Data(ismember(Data.subject, Sub_Comp),:);

% Generate an array for each rater with x,y,z coordinates. 4D array: fids x
% coordinates x subjects x raters. 
Tot_Data = zeros(32,5,length(Sub_Comp), length(raters));
for r = 1:length(raters)
     temp_data = table2array(Data_comp(ismember(Data_comp.rater, raters(r)),[1:4,6]));
     for s = 1:length(Sub_Comp)
         tempData = temp_data(ismember(temp_data(:,5),(Sub_Comp(s))),:);
         [~,idx] = sort(tempData(:,1)); % sort just the first column
         Tot_Data(:,:,s,r) = tempData(idx,:);
     end
end


% Difference between raters
% Define the 2 raters
goldStandard = "MA";
rater = 2;

Coor_Diff = squeeze(Tot_Data(:,:,:,ismember(raters, goldStandard)) - Tot_Data(:,:,:,rater));
rater_error = sqrt(Coor_Diff(:,2,:).^2 + Coor_Diff(:,3,:).^2 + Coor_Diff(:,4,:).^2);
rater_data = [Tot_Data(:,:,:,rater), rater_error];
check_data = [];
for isub = 1:length(rater_data(1,1,:))
    check_data = [check_data;rater_data(rater_data(:,6,isub)> 5.0,5,isub),...
                    rater_data(rater_data(:,6,isub)> 5.0,1,isub)...
                    rater_data(rater_data(:,6,isub)> 5.0,2,isub)...
                    rater_data(rater_data(:,6,isub)> 5.0,3,isub)...
                    rater_data(rater_data(:,6,isub)> 5.0,4,isub)...
                    Coor_Diff(rater_data(:,6,isub)> 5.0,2,isub)...
                    Coor_Diff(rater_data(:,6,isub)> 5.0,3,isub)...
                    Coor_Diff(rater_data(:,6,isub)> 5.0,4,isub)];
end

check_data = array2table(check_data,'VariableNames',{'subject','fid','X','Y','Z','X_diff','Y_diff','Z_diff'});

fclose('all')


%% Generate mean coordinates for gold standard + non-gold standard raters

GS_raters = ["GG", "MA"];

GS_mean = squeeze(mean(Tot_Data(:,:,:,ismember(raters,GS_raters)),4));
NGS_mean =  squeeze(mean(Tot_Data(:,:,:,~ismember(raters,GS_raters)),4));

% Diff between GS vs NGS

GS_Diff = GS_mean - NGS_mean;
GS_error_rate = sqrt(GS_Diff(:,2,:).^2 + GS_Diff(:,3,:).^2 + GS_Diff(:,4,:).^2);

% Mean error between GS and NGS across subjects

Mean_GS_Diff = mean(GS_Diff,3);


% Preliminary figure
for fid = 1:32
    plot3(Mean_GS_Diff(fid,2),Mean_GS_Diff(fid,3),Mean_GS_Diff(fid,4),'o','Color','b','MarkerSize',10,'MarkerFaceColor',[217/255,1,1])
    text(Mean_GS_Diff(fid,2),Mean_GS_Diff(fid,3),Mean_GS_Diff(fid,4),num2str(fid),'FontSize',14,'FontWeight','bold')
    hold on
end
grid on
axis equal
xl = max(abs(xlim()));xl = linspace(xl,-xl,2);
yl = max(abs(ylim()));yl = linspace(yl,-yl,2);
zl = max(abs(zlim()));zl = linspace(zl,-zl,2);
line(2*xl, [0,0], [0,0], 'LineWidth', 1, 'Color', 'k');
line([0,0], 2*yl, [0,0], 'LineWidth', 1, 'Color', 'k');
line([0,0], [0,0], 2*zl, 'LineWidth', 1, 'Color', 'k');

xlabel('X coord')
ylabel('Y coord')
zlabel('Z coord')


%% Inter-rater reliability

% Using intraclass correlation (ICC(2,1)) as described by Shrout, P. E., & Fleiss, J. L. (1979). Intraclass correlations: Uses in assessing rater reliability. Psychological Bulletin, 86(2), 420-428.
% Goal is calculate ICC for each fiducial for each axis

% Matrix containing each statistic(BMS,JMS,WMS,EMS,ICC ; dim1) for each fid (dim 2) in each axis (dim 3)
ICC_Stats = zeros(5,32,3);

Raters_ICC = ["GG", "MA", "AT"];

ICC_Data = squeeze(Tot_Data(:,2:4,:,ismember(raters,Raters_ICC)));

% n = number of samples, k = number of raters
[~,~,n,k] = size(ICC_Data);

% Mean across subjects
Mean_Sub = squeeze(mean(ICC_Data,3));

% Mean across raters
Mean_Rat = squeeze(mean(ICC_Data,4));

% Grand mean
Mean_Grand = squeeze(mean(Mean_Sub,3));

% Calculate between-subject (target) mean square (BMS) for each fidicial +
% axis
ICC_Stats(1,:,:) = sum((((Mean_Rat - Mean_Grand).^2)*k),3)/(n-1);


% Calculate between-rater (judge) mean square (JMS) for each fidicial +
% axis

ICC_Stats(2,:,:) = sum((((Mean_Sub - Mean_Grand).^2)*n),3)/(k-1);


% Calculate within-target (subject) mean square (WMS) for each fidicial +
% axis

ICC_Stats(3,:,:) = squeeze(mean(var(ICC_Data,0,4),3));

% Calculate within-target (subject) residual mean square (EMS) for each fidicial +
% axis

ICC_Stats(4,:,:) = (ICC_Stats(3,:,:)*(n*(k-1)) - ICC_Stats(2,:,:)*(k-1))/((n-1)*(k-1));

% Calculate ICC

ICC_Stats(5,:,:) = (ICC_Stats(1,:,:) - ICC_Stats(4,:,:))./(ICC_Stats(1,:,:) + ICC_Stats(4,:,:)*(k-1) + (ICC_Stats(3,:,:) - ICC_Stats(5,:,:))*k/n);

Final_ICC = squeeze(ICC_Stats(5,:,:));


