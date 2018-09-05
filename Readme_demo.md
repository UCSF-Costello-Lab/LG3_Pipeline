Steps to run test job on CCC

Quick start

1. Change directory to the root of the pipeline repository, e.g.

cd /home/jocostello/shared/LG3_Pipeline

2. Preparations (do once)

Create symbolic link to resource directory: /home/jocostello/shared/LG3_Pipeline_HIDE/resources
Create symbolic link to tools directory: /home/jocostello/shared/LG3_Pipeline_HIDE/tools
Create symbolic link to AnnoVar directory: /home/jocostello/shared/LG3_Pipeline_HIDE/AnnoVar
Create symbolic link to test sample table: /home/jocostello/shared/LG3_Pipeline/runs_demo/patient_ID_conversions.demo

	```
	ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/resources resources
	ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/tools tools
	ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/AnnoVar AnnoVar
	ln -s runs_demo/patient_ID_conversions.demo patient_ID_conversions.txt
	```

3. Copy _run_Trim_P157 script to the main directory and run it (~4-5h)

	```
	cp runs_demo/_run_Trim_P157 .

	_run_Trim_P157
	```


4. Copy _run_Align_gz_P157 script to the main directory and run it (~10-16h)

	```
	cp runs_demo/_run_Align_gz_P157 .

	_run_Align_gz_P157
	```

5. Copy _run_Recal_P157_3 script to the main directory and run it (~85h)

	```
	cp runs_demo/_run_Recal_P157_3 .

	_run_Recal_P157_3
	```

6a. Copy _run_Pindel_157 script to the main directory and run it

	```
	cp runs_demo/_run_Pindel_157 .

	_run_Pindel_157
	```

6b. Copy _run_MutDet_P157 script to the main directory and run it

	```

	cp runs_demo/_run_MutDet_P157 .

	_run_MutDet_P157
	``` 


7. Copy _run_PostMut_P157 script to the main directory and run it

	```

	cp runs_demo/_run_PostMut_P157 .

	_run_PostMut_P157
	```


