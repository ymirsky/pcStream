function approx_rank=find_rank(s,rho)

% s=diag(10:-0.5:1);
% rho=90;

[row,column]=size(s);
s=s.^2;
total_mass=sum(sum(s));
needed_mass=(total_mass*rho)/100;
go_on=1;
mass_temp=0;
loc=1;
while go_on==1
    mass_temp=mass_temp+s(loc,loc);
    if needed_mass<mass_temp
        go_on=0;
        approx_rank=loc;
    else
        loc=loc+1;
    end
end
    


