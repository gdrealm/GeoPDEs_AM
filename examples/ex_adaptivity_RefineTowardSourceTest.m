%% EX_ADAPTIVITY_REFINETOWARDSOURCETEST
% Test the refine/coarse toward source functions
% 
%
%
% Copyright (C) 2017 Massimo Carraturo
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.

%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.

clear problem_data
close all
clc
% Initial domain, defined as NURBS map given in a text file
problem_data.geo_name = 'geo_square.txt';

% CHOICE OF THE DISCRETIZATION PARAMETERS (Initial mesh)
clear method_data
method_data.degree      = [2 2];        % Degree of the splines
method_data.regularity  = [1 1];        % Regularity of the splines
method_data.nsub_coarse = [2 2];        % Number of subdivisions of the coarsest mesh, with respect to the mesh in geometry
method_data.nsub_refine = [2 2];        % Number of subdivisions for each refinement
method_data.nquad       = [3 3];        % Points for the Gaussian quadrature rule
method_data.space_type  = 'standard';   % 'simplified' (only children functions) or 'standard' (full basis)
method_data.truncated   = 1;            % 0: False, 1: True

% Source path
x_begin = 0.5;
x_end = 10.5;
x_path = linspace(x_begin, x_end, 2);
y_begin = 0.55;
y_end = 10.5;
y_path = linspace(y_begin, y_end, 2);
problem_data.path = [x_path', y_path'];

% ADAPTIVITY PARAMETERS
clear adaptivity_data
adaptivity_data.flag = 'elements';
adaptivity_data.C0_est = 1.0;
adaptivity_data.nsub_refine = [2 2];        
adaptivity_data.mark_param = 0.75;
adaptivity_data.mark_param_coarsening = 0.01;
adaptivity_data.mark_neighbours = true;
adaptivity_data.mark_strategy = 'MS';
adaptivity_data.max_level = 5;
adaptivity_data.max_ndof = 15000;
adaptivity_data.num_max_iter = 20;
adaptivity_data.max_nel = 15000;
adaptivity_data.tol = 1.0e-03;
adaptivity_data.radius = [0.00001, 0.00001];
adaptivity_data.crp = 1.0;   

% GRAPHICS
plot_data.plot_hmesh = false;
plot_data.adaptivity = false;
plot_data.plot_discrete_sol = false;
plot_data.print_info = false;
plot_data.plot_matlab = false;
plot_data.npoints_x = 100;       %number of points x-direction in post-processing
plot_data.npoints_y = 100;       %number of points y-direction in post-processing
plot_data.npoints_z = 1;        %number of points z-direction in post-processing

%% Generate the first level of initial mesh
[geometry, boundaries, interfaces, ~, boundary_interfaces] = mp_geo_load (problem_data.geo_name);

[knots, zeta] = kntrefine (geometry.nurbs.knots, method_data.nsub_coarse-1, method_data.degree, method_data.regularity);
% tensor product level 1
rule     = msh_gauss_nodes (method_data.nquad);
[qn, qw] = msh_set_quad_nodes (zeta, rule);
msh   = msh_cartesian (zeta, qn, qw, geometry);
space = sp_bspline (knots, method_data.degree, msh);
% hierarchical space
hmsh     = hierarchical_mesh (msh, method_data.nsub_refine);
hspace   = hierarchical_space (hmsh, space, method_data.space_type, method_data.truncated);

%% Add second and thrid level using THB-refinement
% Second level
marked_ref = cell(1, hspace.nlevels);
marked_ref{1} = [1 2 3 4];
[hmsh, hspace, ~] = adaptivity_refine (hmsh, hspace, marked_ref, adaptivity_data);
hmsh_plot_cells (hmsh, 20, 1 );

% add new level

hmsh.nlevels = hmsh.nlevels + 1;
hmsh.active{hmsh.nlevels} = [];
hmsh.deactivated{hmsh.nlevels} = [];
hmsh.nel_per_level(hmsh.nlevels) = 0;
hmsh.mesh_of_level(hmsh.nlevels) = msh_refine (hmsh.mesh_of_level(hmsh.nlevels-1), hmsh.nsub);
hmsh.msh_lev{hmsh.nlevels} = [];

% assign dofs
v1 = [1 1.0 1.0 1.0 1 1 1 1 1 1]';
v2 = [1.0 1.1 1.1 1.1 1.3 1.4]';
v3 = [1.75 1.4 0.8 1.5 1.75 1.6]';
v4 = v3*1.5;


hspace.dofs = cat(1, v1, v2, v3, v4, v2, [1.4, 2]');
initial_values = hspace.dofs;

% plot initial state
npts = [plot_data.npoints_x plot_data.npoints_y ];
[eu, F] = sp_eval (initial_values, hspace, geometry, npts);
figure(4); surf (squeeze(F(1,:,:)), squeeze(F(2,:,:)), eu)

%% Refinement
[ marked_ref, ~ ] = refine_toward_source( hmsh, hspace, 1, adaptivity_data, problem_data );
[hmsh, hspace, Cref] = adaptivity_refine (hmsh, hspace, marked_ref, adaptivity_data);
hmsh_plot_cells (hmsh, 20, (figure(2)));
u_ref = Cref*initial_values;

% plot refined state
npts = [plot_data.npoints_x plot_data.npoints_y ];
[eu, F] = sp_eval (u_ref, hspace, geometry, npts);
figure(6); surf (squeeze(F(1,:,:)), squeeze(F(2,:,:)), eu)


[ marked_ref, ~ ] = refine_toward_source( hmsh, hspace, 1, adaptivity_data, problem_data );
[hmsh, hspace, Cref] = adaptivity_refine (hmsh, hspace, marked_ref, adaptivity_data);
hmsh_plot_cells (hmsh, 20, (figure(3)));
hspace.dofs = Cref*u_ref;

% plot refined state
npts = [plot_data.npoints_x plot_data.npoints_y ];
[eu, F] = sp_eval (hspace.dofs, hspace, geometry, npts);
figure(6); surf (squeeze(F(1,:,:)), squeeze(F(2,:,:)), eu)

%% Coarsening back to the initial state
[marked_coarse, ~ ] = coarse_toward_source( hmsh, hspace, 1, adaptivity_data, problem_data );
[hmsh, hspace, u] = adaptivity_coarsen(hmsh, hspace, marked_coarse, adaptivity_data);
hmsh_plot_cells (hmsh, 20, (figure(4)));

% plot coarse state
npts = [plot_data.npoints_x plot_data.npoints_y];
[eu, F] = sp_eval (u, hspace, geometry, npts);
figure(7); surf (squeeze(F(1,:,:)), squeeze(F(2,:,:)), eu)

[ marked_coarse, ~ ] = coarse_toward_source( hmsh, hspace, 2, adaptivity_data, problem_data );
[hmsh, hspace, u] = adaptivity_coarsen(hmsh, hspace, marked_coarse, adaptivity_data);
hmsh_plot_cells (hmsh, 20, (figure(5)));


% plot coarse state
npts = [plot_data.npoints_x plot_data.npoints_y];
[eu, F] = sp_eval (u, hspace, geometry, npts);
figure(8); surf (squeeze(F(1,:,:)), squeeze(F(2,:,:)), eu);