import json
with open("repo.json") as f:
     data=json.load(f)

lastImageTag = (data['imageDetails'])[-1]['imageTags'][-1]
print(lastImageTag)
