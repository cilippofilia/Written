//
//  Prompts.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import Foundation

public let loremIpsum = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.

Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur? At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga.
"""

public let reflectivePrompt = """
Below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.
Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
Do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.
Ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.
Else, start by saying, "hey, thanks for showing me this. my thoughts:"
        
My entry:


"""

public let insightfulPrompt = """
Take a look at my journal entry below. I'd like you to analyze it and respond with deep insight that feels personal, not clinical.
Imagine you're not just a friend, but a mentor who truly gets both my tech background and my psychological patterns. I want you to uncover the deeper meaning and emotional undercurrents behind my scattered thoughts.
Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
Use vivid metaphors and powerful imagery to help me see what I'm really building. Organize your thoughts with meaningful headings that create a narrative journey through my ideas.
Don't just validate my thoughts - reframe them in a way that shows me what I'm really seeking beneath the surface. Go beyond the product concepts to the emotional core of what I'm trying to solve.
Be willing to be profound and philosophical without sounding like you're giving therapy. I want someone who can see the patterns I can't see myself and articulate them in a way that feels like an epiphany.
Start with 'hey, thanks for showing me this. my thoughts:' and then use markdown headings to structure your response.
    
Here's my journal entry:


"""

public let actionableSuggestionPrompt = """
Take a look at my journal entry below. I need you to help me move from thinking to doing.
Don't just reflect back what I'm feeling - help me see the concrete next steps hidden in my rambling. What am I actually trying to build? What's the first move? What am I avoiding?
Keep it casual and direct. Challenge me when I'm overthinking. Point out where I'm stuck in analysis paralysis versus where I'm onto something real.
Use markdown headings to break down: what's actually worth pursuing, what's distraction, and what I should do this week. Be honest about what sounds like procrastination dressed up as planning.
Start with 'hey, thanks for showing me this. my thoughts:' and then give me a roadmap.

Here's my journal entry:


"""

public var validatingPrompt = """
Take a look at my journal entry below. Right now I just need someone to tell me I'm not crazy and that what I'm feeling makes sense.
I don't need solutions or challenges or deep analysis. I need you to sit with me in this and help me feel less alone in whatever I'm going through. Find the threads of what's real and legitimate in my experience.
Keep it warm and human. Help me see that my thoughts and feelings are reasonable responses to whatever's happening. Normalize what I'm going through without minimizing it.
Use markdown headings if it helps, but mostly just... be with me in this. Remind me of my own strength and resilience when I can't see it myself.
Start with 'hey, thanks for showing me this. my thoughts:' and then just be genuinely supportive.

Here's my journal entry:


"""

public var challengingPrompt = """
Take a look at my journal entry below. I need you to call me on my bullshit.
I'm probably rationalizing something, avoiding something, or lying to myself about something. Help me see where I'm being inconsistent, where my actions don't match my words, or where I'm making excuses.
Don't be mean, but don't be soft either. I trust you enough to be honest with me. Point out the contradictions, the patterns I keep repeating, the ways I might be self-sabotaging.
Keep it real and direct. Use markdown headings to organize your thoughts, but don't sugarcoat. Sometimes I need someone to shake me out of my own narratives.
Start with 'hey, thanks for showing me this. my thoughts:' and then tell me what I need to hear, not what I want to hear.

Here's my journal entry:


"""
