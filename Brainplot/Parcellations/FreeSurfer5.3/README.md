Included surface labels
=======================

The following `.label` files are included under each mesh's own `label/` directory. All 16 files were copied without modification from `E:\Resources\GRETNA_CW\Parcellations\FreeSurfer5.3` and verified byte-for-byte against that source. Vertex indices were checked against the matching surface resolution.

| Surface | Vertices per hemisphere | Included labels (both `lh` and `rh`) |
| --- | --- | --- |
| `fsaverage` | 163842 | `cortex`, `Medial_wall`, `aparc`, `oasis.chubs.medialpfc` |
| `fsaverage5` | 10242 | `cortex`, `Medial_wall` |
| `fsaverage6` | 40962 | `cortex`, `Medial_wall` |

There are 16 `.label` files in total. The current Brainplot examples use `fsaverage` and read `fsaverage/label/lh.cortex.label` and `fsaverage/label/rh.cortex.label`. The retained `fsaverage/surf/lh.sphere` and `rh.sphere` are original files and match the specified GRETNA_CW source byte-for-byte.

The specified source does not contain `surf/lh.sphere` or `surf/rh.sphere` for `fsaverage5` or `fsaverage6`. These four files are therefore absent here; the previously converted versions have been removed. `CBIG_ReadNCAvgMesh` requires these sphere files even when loading an inflated surface. Before using either lower resolution with that reader, supply its corresponding original FreeSurfer sphere files. No converted sphere files are included.

When moving the toolbox, copy the complete `Brainplot` directory and preserve the `surf/` and `label/` subdirectories. Use labels and surfaces from the same resolution. The Schaefer200 annotations used by the examples remain in `Brainplot/example/`; this update adds surface labels, not the full annotation collection described below.

References
==========
+ Schaefer A, Kong R, Gordon EM, Laumann TO, Zuo XN, Holmes AJ, Eickhoff SB, Yeo BTT. [**Local-Global parcellation of the human cerebral cortex from intrinsic functional connectivity MRI**](http://people.csail.mit.edu/ythomas/publications/2018LocalGlobal-CerebCor.pdf), *Cerebral Cortex*, 29:3095-3114, 2018
+ Yeo BTT, Krienen FM, Sepulcre J, Sabuncu MR, Lashkari D, Hollinshead M, Roffman JL, Smoller JW, Zöllei L, Polimeni JR, Fischl B, Liu H, Buckner RL. [**The organization of the human cerebral cortex revealed by intrinsic functional connectivity**](http://people.csail.mit.edu/ythomas/publications/2011CorticalOrganization-JNeurophysiol.pdf), *J Neurophysiology*, 106(3):1125-1165, 2011

----

Background
==========
Resting state fMRI data from 1489 subjects were registered using surface-based alignment. A gradient weighted markov random field approach was employed to identify cortical areas.

----

Information about Downloads
===========================
There are three folders corresponding to the `fsaverage`, `fsaverage5` and `fsaverage6` surface space. `fsaverage` contains the high resolution version of the parcellation, while `fsaverage6` and `fsaverage5` contain lower resolution versions of the parcellation. 

The parcellations were computed in `fsaverage6` space and sampled to `fsaverage5` and `fsaverage`. Each parcel was matched to a corresponding network in the 7 and 17 network parcellation by Yeo et al. Please notice that all labels were created in freesurfer version 5.3 and are maybe not be fully functional in other versions of freesurfer.

The structure of each folder follows that of a preprocessed freesurfer subject. In particular, `fsaverage/label/`, `fsaverage5/label/`, `fsaverage6/label/` contain all the parcellation and confidence files. For example, `fsaverage/label/lh.Schaefer2018_400Parcels_7Networks_order.annot` is the 400 areas parcellation on the left hemisphere ordered and colored according to Yeo et al. 2011.

----

Example Usage
=============
Make sure freesurfer has been set up and configured as usual (http://surfer.nmr.mgh.harvard.edu/fswiki/SetupConfiguration).  

In terminal,  

1) `cd` to unzipped folder containing this README file, fsaverage, fsaverage6, fsaverage5  

2) run the following command:

```   
freeview -f fsaverage/surf/lh.inflated:annot=fsaverage/label/lh.Schaefer2018_400Parcels_17Networks_order.annot  
```

----

Bugs and Questions
==================
Please contact Alexander Schaefer at alexschaefer83@gmail.com and Thomas Yeo at yeoyeo02@gmail.com.
