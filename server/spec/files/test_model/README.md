The test model is a simple building with 4 measures. If you replace this test 
model, then you must also replace the .zip, .json, and the measures/seed/weather
directories.

# Rebuilding Test Zip/JSON

zip -r test_model.zip . -x \*.DS_Store -x tmp_run_single\* -x test_model.json -x README.md