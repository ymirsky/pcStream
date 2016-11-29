function [avg_mass,total_mass]=get_avg_vec_norm(A)

[row,column]=size(A);
total_mass=0;
for term=1:column
    total_mass=total_mass+norm(A(:,term));
end
avg_mass=total_mass/column;