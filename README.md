# Feature Flagging


## Overview

When I was working on the miPic app, I was eager to implement a feature flagging tool. This not only to be able to hide unfinished features behind a flag, but also to show the rest of the team the power of feature flagging, from a/b split testing to being able to remotely change things indapendantly of a back end.

I was an early adopter of Firebase remote config, and quickly was able to build a basic feature flagging tool into the app. I even had created a hidden debugging menu appropeiatley named Area 51, that was only accessible in our interal build of the app.

Once the feature flagging was possible in the app, I wrapped a UI around it that was accessible inside area 51. This allowed team memebers such as QA's and our product owner to be able to easily flag features on and off locally, without having to understand how to use the firebase dashboard. They buy-in was immediate, very quickly I was being asked to leverage feature flagging more frequestly, for example being able to show a Black Friday sales banner, that we could remotely update the text and promo codes

Though an extremely useful and powerful, the pain points of my original implimentation became apperent very quickly. 

To add a new feature flag involved various steps:

1. Add the new flag to firebase remote config
2. add the new flag constant to our feaature flags constant file
3. create a new Feature object in our feature flags array
4. Using the flag meant using a very verbose api

```
guard FeatureFlagsManager.shared.string(for: FeatureFlagKey.applePayEnabled) else {
    return false
}
```

This was not a scaleable solution, so I decided to try an automate the process as much as possible and clean up the api. 

This automation is the subject of the article.

## Implementation


### Compile time Scripting!!!

#### Config Files

One of my favourite things about swift is the ability to use it for scripting. My goal was to use a script to generate a few key files and only leave the actual use of the flag as the manual step.
the first step was to move away from hard-coding all of the various flags and use a json config file, meaning we could simply configure our flags in one place.

```
[
    {
        "name": "featureA",
        "description": "Cool feature A that is a bool",
        "value": false
    },
    {
        "name": "featureB",
        "description": "another cool feature, that is a string",
        "value": "use code SALE to get 25% off"
    }
]
```

In conjuection with this json file, I created a plist config file to declare the following properties

 | Key                       | Description           		   	    |
 | ------------------------- | ------------------------------------ |
 |	inputilePath			 |	file pah feature flags json file    | 
 |	outpuFilePath			 |	file pah for generated files        | 
 |	outpuFilename			 |	filename/prefix for generated file  | 


leveraging config files allowed me to build a flexible and resuable tool, which could be used by any future projects or even open-sourced...when I had the time.


##### The Script

The next step was to create a script that could use these config files and generate `.swift` files that would be used inside the miPic codebase.

For the above example json file, the script would ouput the following:

```

enum FeatureVariable: String {
    case showCheckoutReviewRequest
    case showPublicUploadReviewRequest
}

protocol FeatureFlagManager {
    func string(for key: String) -> String
    func bool(for key: String) -> Bool
    func int(for key: String) -> Int
    func double(for key: String) -> Double
}

class FeatureFlags {
    let featureManager: FeatureManager

    init(featureManager: FeatureManager) {
        self.featureManager = featureManager
    }

    var featureA: Bool {
        featureManager.bool(for: FeatureVariable.featureA.rawValue)
    }

    var featureB: String {
        featureManager.string(for: FeatureVariable.featureB.rawValue)
    }
}
```

There are 3 key things that we now got for free without any manual intervention

1. `FeatureVariable`
An enum that has cases for each feature flag key

2. `FeatureFlagManager`

A protocol that a concrete feature flag manager should conform to, one that is backed by a feature flagging library, for example Firebase remote config. It allows us to fetch values such a bool, string or Int.

3. `FeatureFlags`

Finally our feature flagging concrete class, this can be injected around our codebase enabling us to access feature flag variables.


In addition to this files being automatically generated, as you can see, we now have vars that have their own getter functions declared, meaning we can move away from this:
```
guard FeatureFlagsManager.shared.string(for: FeatureFlagKey.applePayEnabled) else {
    return false
}
```

and now usse this

```
guard featureFlags.applePayEnabled else {
    return false
}
```

a more clean and friendly api. Also notice we are no longer using the shared instance of the Feature Flag Manager!


##### pre-build phase

The next important step was to put this into an automation flow. The ideal candiated was using Xcodes build phases, where we can run the script at compile time. 
With this now in places our new work flow would be:

1. Add the new flag to firebase remote config
2. add the new flag to our feature flags json config file

Now when the app is built, we have access to the feature flag in code!


### Feature Flags Manager

From an implementation point, the only customisations needed are to create a concrete class for our `FeatureFlagManager` protocol

The feature flag manager is responsible for retrieving values in a given priortiy order which is as follows:

 - 1. First checks local cache (UserDefaults), as we may have updated a value using the debug menu, if one is found it takes priority
 - 2. If there is no local value, we try to use the latest remote value.
 - 3. if the remote value can not be found - maybe due to no connection, on first load, or there is no remote value for this key - we use the json config file as the fall back

This is illustrated in the below flow diagram.

![Feature Flags Priority Flow](https://user-images.githubusercontent.com/3674185/156943997-db48b1e0-929b-41f5-94a2-d690ed937ef1.jpg)

Given the value could be of any type, we use a generic function to fetch the value from the priority order:

```
    func value<T>(for key: String, _ type: T.Type) -> T? {
        if let localValue = localValue(for: key) as? T {
            return localValue
        } else if let remoteValue = firebaseRemoteConfig.remoteData[key] as? T {
            return remoteValue
        } else if let defaultValue = defaultValue(for: key, T.self) {
            return defaultValue
        }
        return nil
    }
```

Here we are fetching the default fall back value from the json config file:

```
 func defaultValue<T>(for key: String, _ type: T.Type) -> T? {
        defaultValues
            .filter { $0.name == key }
            .compactMap {
                guard let value = $0.value as? T else { return nil }
                return value
            }
            .first
    }
```

A value is cached locally in `UserDefaults` via the feature flag debug menu, any time a value is changed in that menu we cache it so it takes priorty order when read.

Below is a diagram on how the config files, script, generated files and debug menu interact.

## Diagram

![Feature Flagging](https://user-images.githubusercontent.com/3674185/156943989-707e739e-163e-4f09-941d-45b4cc533eec.jpg)


